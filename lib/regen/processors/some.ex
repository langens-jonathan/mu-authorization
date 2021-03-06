alias Regen.Processors.Some, as: Some

defmodule Some do
  alias Regen.Status, as: State

  defstruct [
    # expression version of the parsed element
    :element,
    # state we started at
    {:state, %State{}},
    # generator for our own child element
    {:selfgenerator, :none},
    # generator for our substates child element
    {:restgenerator, :none},
    # array of states which are already used as a basis for output
    {:locked_states, []}
  ]

  @type t :: %Some{}

  defimpl Regen.Protocol do
    def emit(%Some{} = some) do
      Some.walk(some)
    end
  end

  def walk(%Some{} = some) do
    case some
         |> ensure_selfgenerator_exists
         |> ensure_restgenerator_exists do
      {:ok, some} ->
        some
        |> emit_restgenerator_result

      {:ok, next_generator_state, state} ->
        # last result
        {:ok, next_generator_state, state}

        # dialyzer informs us this state cannot arrive.  Leaving it here
        # for when bugs arrive

        # _ ->
        #   if locked_state?(some, state) do
        #     {:fail}
        #   else
        #     # the self generator failed to yield a result, our current
        #     # state is the last state
        #     {:ok, %Regen.Processors.None{}, state}
        #   end
    end
  end

  def ensure_selfgenerator_exists(
        %Some{selfgenerator: :none, element: element, state: state} = some
      ) do
    %{some | selfgenerator: Regen.Constructor.make(element, state)}
  end

  def ensure_selfgenerator_exists(%Some{} = some) do
    some
  end

  def ensure_restgenerator_exists(
        %Some{
          selfgenerator: selfgen,
          restgenerator: :none,
          state: state,
          locked_states: locked_states
        } = some
      ) do
    case Regen.Protocol.emit(selfgen) do
      {:ok, new_selfgen, result} ->
        if locked_state?(some, result) do
          # if we are now in a locked state, skip it
          walk(%{some | selfgenerator: new_selfgen})
        else
          # generate a new result with our state as the new base state
          {:ok,
           %{
             some
             | restgenerator: %{
                 some
                 | state: result,
                   selfgenerator: :none,
                   restgenerator: :none,
                   locked_states: [state | locked_states]
               },
               selfgenerator: new_selfgen
           }}
        end

      _ ->
        # Emit our own state as a result
        {:ok, %Regen.Processors.None{}, state}
    end
  end

  def ensure_restgenerator_exists(%Some{} = some) do
    {:ok, some}
  end

  def locked_state?(%Some{locked_states: locked}, state) do
    Enum.member?(locked, state)
  end

  def emit_restgenerator_result(%Some{restgenerator: restgen} = some) do
    case Regen.Protocol.emit(restgen) do
      {:ok, new_restgen, state} ->
        {:ok, %{some | restgenerator: new_restgen}, state}

      _ ->
        # Emit a new result from our selfgenerator and continue walking
        walk(%{some | restgenerator: :none})
    end
  end
end
