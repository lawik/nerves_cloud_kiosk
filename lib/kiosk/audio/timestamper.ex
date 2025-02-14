defmodule Kiosk.Audio.Timestamper do
  # TODO: Document what this module does and is for
  # TODO: It adds timestamps to a stream that we can use for transcripts to ensure we know
  # TODO: where in time the transcripts happen
  use Membrane.Filter

  require Logger

  def_options(
    bytes_per_second: [
      spec: :any,
      default: nil,
      description: "Bytes per second"
    ]
  )

  def_input_pad(:input,
    availability: :always,
    flow_control: :manual,
    demand_unit: :buffers,
    accepted_format: _any
  )

  def_output_pad(:output,
    availability: :always,
    flow_control: :manual,
    accepted_format: _any
  )

  @impl true
  def handle_init(_ctx, %__MODULE{
        bytes_per_second: bytes_per_second
      }) do
    # We determine time by bytesize
    millisecond_bytes = bytes_per_second / 1000

    state = %{
      millisecond_bytes: millisecond_bytes,
      processed_bytes: 0,
      count_in: 0,
      count_out: 0
    }

    {[], state}
  end

  @impl true
  def handle_playing(_ctx, state) do
    {[demand: {:input, 1}], state}
  end

  @impl true
  def handle_buffer(:input, %Membrane.Buffer{} = buffer, _context, state) do
    state = %{state | count_in: state.count_in + 1}

    byte_count = IO.iodata_length(buffer.payload)
    duration = floor(byte_count / state.millisecond_bytes)
    start_ts = floor(state.processed_bytes / state.millisecond_bytes)
    state = %{state | processed_bytes: state.processed_bytes + byte_count}
    end_ts = floor(state.processed_bytes / state.millisecond_bytes)
    metadata = buffer.metadata || %{}

    out_buffer =
      {:output,
       %{
         buffer
         | metadata:
             Map.merge(metadata, %{
               start_ts: start_ts,
               end_ts: end_ts,
               duration: duration
             })
       }}

    actions = [demand: {:input, 1}, buffer: out_buffer]

    {actions, %{state | count_out: state.count_out + 1}}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _context, state) do
    {[demand: {:input, size}], state}
  end

  @impl true
  def handle_end_of_stream(_pad, _context, state) do
    {[end_of_stream: :output], state}
  end
end
