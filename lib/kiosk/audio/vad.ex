defmodule Kiosk.Audio.VAD do
  use Membrane.Filter

  def_input_pad(:input,
    availability: :always,
    flow_control: :manual,
    demand_unit: :buffers,
    accepted_format: Membrane.RawAudio
  )

  def_output_pad(:output,
    availability: :always,
    flow_control: :manual,
    accepted_format: Membrane.RawAudio
  )

  @impl true
  def handle_init(_ctx, _mod) do
    # using https://raw.githubusercontent.com/snakers4/silero-vad/v4.0stable/files/silero_vad.onnx
    model =
      :kiosk
      |> :code.priv_dir()
      |> Path.join("silero_vad.onnx")
      |> Ortex.load()

    min_ms = 100

    sample_rate_hz = 16000
    sr = Nx.tensor(sample_rate_hz, type: :s64)
    n_samples = min_ms * (sample_rate_hz / 1000)

    bytes_per_chunk = n_samples * 2
    IO.inspect(bytes_per_chunk, label: "bytes per chunk")

    init_state = %{
      h: Nx.broadcast(0.0, {2, 1, 64}),
      c: Nx.broadcast(0.0, {2, 1, 64}),
      n: 0,
      sr: sr
    }

    IO.inspect(init_state, label: "state")
    IO.inspect(model, label: "model")

    state = %{
      run_state: init_state,
      model: model,
      bytes: bytes_per_chunk,
      buffered: [],
      speaking?: false
    }

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

      input =
        data
        |> Nx.from_binary(:f32)
        |> List.wrap()
        |> Nx.stack()

      {output, hn, cn} = Ortex.run(state.model, {input, sr, h, c})
      prob = output |> Nx.squeeze() |> Nx.to_number()

      # IO.puts("Chunk ##{n}: #{Float.round(prob, 3)}")
      run_state = %{c: cn, h: hn, n: n + 1, sr: sr}
      state = %{state | run_state: run_state, buffered: []}

      if prob > 0.5 do
        if state.speaking? do
          {[demand: {:input, 1}, buffer: {:output, buffer}], state}
        else
          {[
             demand: {:input, 1},
             buffer: {:output, buffer},
             notify_parent: {:speaking, :start, prob}
           ], %{state | speaking?: true}}
        end
      else
        # buffer_size = byte_size(buffer.payload) * 8
        # Pass unnmodified buffer on no speech
        buffer = buffer
        # only pass speaking?
        # {[demand: {:input, 1}], state}
        # pass 0-padded data
        # {[demand: {:input, 1}, buffer: {:output, %{buffer | payload: <<0::size(buffer_size)>>}}],
        # state}
        if state.speaking? do
          {[
             demand: {:input, 1},
             buffer: {:output, buffer},
             notify_parent: {:speaking, :stop, prob}
           ], %{state | speaking?: false}}
        else
          {[demand: {:input, 1}, buffer: {:output, buffer}], state}
        end
      end
    else
      %{state | buffered: buffered}
      {[demand: {:input, 1}], state}
    end
  end
end
