defmodule Explorer.Chain.Cache.AddressSumMinusBurnt do
  @moduledoc """
  Cache for address sum minus burnt number.
  """

  require Logger

  use Explorer.Chain.MapCache,
    name: :address_sum_minus_burnt,
    key: :sum_minus_burnt,
    key: :async_task,
    ttl_check_interval: Application.get_env(:explorer, __MODULE__)[:ttl_check_interval],
    global_ttl: :infinity,
    callback: &async_task_on_deletion(&1)

  alias Explorer.{Chain, Etherscan}
  alias Explorer.Chain.Cache.Helper

  defp handle_fallback(:sum_minus_burnt) do
    # This will get the task PID if one exists, check if it's running and launch
    # a new task if task doesn't exist or it's not running.
    # See next `handle_fallback` definition
    safe_get_async_task()

    {:return, Decimal.new(0)}
  end

  defp handle_fallback(:async_task) do
    # If this gets called it means an async task was requested, but none exists
    # so a new one needs to be launched
    {:ok, task} =
      Task.start_link(fn ->
        try do
          result = Etherscan.fetch_sum_coin_total_supply_minus_burnt()

          params = %{
            counter_type: "sum_coin_total_supply_minus_burnt",
            value: result
          }

          Chain.upsert_last_fetched_counter(params)

          set_sum_minus_burnt(%ConCache.Item{ttl: Helper.ttl(__MODULE__, "CACHE_ADDRESS_SUM_PERIOD"), value: result})
        rescue
          e ->
            Logger.debug([
              "Couldn't update address sum: ",
              Exception.format(:error, e, __STACKTRACE__)
            ])
        end

        set_async_task(nil)
      end)

    {:update, task}
  end

  # By setting this as a `callback` an async task will be started each time the
  # `sum_minus_burnt` expires (unless there is one already running)
  defp async_task_on_deletion({:delete, _, :sum_minus_burnt}), do: safe_get_async_task()

  defp async_task_on_deletion(_data), do: nil
end
