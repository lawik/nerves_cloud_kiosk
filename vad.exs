Mix.install([
  {:ortex, "== 0.1.9"},
  :req,
  {:nx, "== 0.7.0"},
  {:membrane_core, "~> 1.0"},
  {:membrane_file_plugin, "~> 0.17.0"},
  {:membrane_portaudio_plugin, "~> 0.19.2"},
  {:membrane_ffmpeg_swresample_plugin, "~> 0.20.2"},
  {:membrane_mp3_mad_plugin, "~> 0.18.3"},
  {:membrane_mp3_lame_plugin, "~> 0.18.2"}
])

defmodule VAD do
  use Membrane.Filter

  def_input_pad :input,
    availability: :always,
    flow_control: :manual,
    demand_unit: :buffers,
    accepted_format: Membrane.RawAudio

  def_output_pad :output,
    availability: :always,
    flow_control: :manual,
    accepted_format: Membrane.RawAudio

  @impl true
  def handle_init(_ctx, _mod) do
    model = Ortex.load("./silero_vad_likely.onnx")

    min_ms = 100

    # herz = per second
    sample_rate_hz = 16000
    sr = Nx.tensor(sample_rate_hz, type: :s64)
    # u8
    #sample_size = 16
    n_samples = min_ms * (sample_rate_hz / 1000)

    #target_size = 16
    #rate = trunc(target_size / sample_size)

    #bytes_per_chunk = trunc(((sample_rate_hz / 1000) * min_ms) * (sample_size / 8))
    # 16 / 8 = 2
    bytes_per_chunk = n_samples * 2
    IO.inspect(bytes_per_chunk, label: "bytes per chunk")

    init_state = %{h: Nx.broadcast(0.0, {2, 1, 64}), c: Nx.broadcast(0.0, {2, 1, 64}), n: 0, sr: sr}
    IO.inspect(init_state, label: "state")
    IO.inspect(model, label: "model")
    state = %{run_state: init_state, model: model, bytes: bytes_per_chunk, buffered: []}
    {[], state}
  end

  @impl true
  def handle_playing(_ctx, state) do
    {[demand: {:input, 1}], state}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {[demand: {:input, size}], state}
  end

  @impl true
  def handle_buffer(:input, %Membrane.Buffer{payload: data} = buffer, _context, state) do
    %{n: n, sr: sr, c: c, h: h} = state.run_state
    buffered = [state.buffered, data]
    if IO.iodata_length(buffered) >= state.bytes do
      data = IO.iodata_to_binary(buffered)
      input = data
        |> Nx.from_binary(:s16)
        |> Nx.as_type(:f32)
        |> List.wrap()
        |> Nx.stack()
      #IO.inspect(input, label: "input")
      #IO.inspect(sr, label: "sr")
      {output, hn, cn} = Ortex.run(state.model, {input, sr, h, c})
      prob = output |> Nx.squeeze() |> Nx.to_number()

      IO.puts("Chunk ##{n}: #{Float.round(prob,3)}")
      run_state = %{c: cn, h: hn, n: n + 1, sr: sr}
      state = %{state | run_state: run_state, buffered: []}
      if prob > 0.9 do
        {[demand: {:input, 1}, buffer: {:output, buffer}], state}
      else
        buffer_size = byte_size(buffer.payload) * 8
        {[demand: {:input, 1}], state}
        #{[demand: {:input, 1}, buffer: {:output, %{buffer | payload: <<0::size(buffer_size)>>}}], state}
      end
    else
      %{state | buffered: buffered}
      {[demand: {:input, 1}], state}
    end
  end
end

defmodule Membrane.Demo.SimplePipeline do
  use Membrane.Pipeline
  @impl true
  def handle_init(_ctx, _) do
    # Setup the flow of the data
    # Stream from file
    spec =
      child(:source, %Membrane.PortAudio.Source{
        channels: 1,
        sample_format: :s16le,
        sample_rate: 16000,
        portaudio_buffer_size: 1600
      })
      # Convert Raw :s24le to Raw :s16le
      # |> child(:converter, %Membrane.FFmpeg.SWResample.Converter{
      #   output_stream_format: %Membrane.RawAudio{
      #     sample_format: :s16le,
      #     sample_rate: 48000,
      #     channels: 2
      #   }
      # })
      |> child(:vad, VAD)
      |> child(:converter, %Membrane.FFmpeg.SWResample.Converter{
        output_stream_format: %Membrane.RawAudio{
          sample_format: :s32le,
          sample_rate: 44_100,
          channels: 2
        }
      })
      # Stream data into PortAudio to play it on speakers.
      |> child(:encoder, Membrane.MP3.Lame.Encoder)
      |> child(:file, %Membrane.File.Sink{location: "local.mp3"})

    {[spec: spec], %{}}
  end
end



#"good.raw"
# "out-16k16.pcm"
# |> File.stream!(bytes_per_chunk)
# |> Enum.reduce(init_state, fn data, %{c: c, h: h, n: n} ->
# end)
Membrane.Pipeline.start_link(Membrane.Demo.SimplePipeline, [])
|> IO.inspect()

:timer.sleep(:infinity)
