::  send-zigs-from-bud-to-wes.hoon:
::  1. send ZIGs tokens from ~bud to ~wes
::  2. confirm ZIGs amounts are as expected after send
::  3. restore state to what it was before sending
::
::  demonstrates the following functions provided by the
::  zig-ziggurat-threads toolkit:
::  1. +send-pyro-scry
::  2. +take-snapshot
::  3. +load-snapshot
::  4. +send-wallet-transaction
::  5. +send-discrete-pyro-poke-then-sleep
::  6. +is-equal:expect
::
/-  spider,
    w=zig-wallet,
    zig=zig-ziggurat
/+  strandio,
    ziggurat-threads=zig-ziggurat-threads
::
=*  strand  strand:spider
=*  scry    scry:strandio
::
=/  m  (strand ,vase)
=|  project-name=@t
=|  desk-name=@tas
=|  ship-to-address=(map @p @ux)
=*  zig-threads
  ~(. ziggurat-threads project-name desk-name ship-to-address)
|^  ted
::
+$  arg-mold
  $:  project-name=@t
      desk-name=@tas
      request-id=(unit @t)
  ==
::
++  town-id
  ^-  @ux
  0x0
::
++  sequencer-host
  ^-  @p
  ~nec
::
++  from
  ^-  @p
  ~bud
::
++  to
  ^-  @p
  ~wes
::
++  zigs-contract-address
  ^-  @ux
  0x74.6361.7274.6e6f.632d.7367.697a
::
++  send-amount
  ^-  @ud
  123.456
::
++  snapshot-path
  ^-  path
  /[project-name]/send-zigs-from-bud-to-wes/0
::
++  get-ship-to-address
  =/  m  (strand ,(map @p @ux))
  ^-  form:m
  ;<  =update:zig  bind:m
    %+  scry  update:zig
    /gx/ziggurat/get-ship-to-address-map/[project-name]/noun
  ?>  ?=(^ update)
  ?>  ?=(%ship-to-address-map -.update)
  ?>  ?=(%& -.payload.update)
  (pure:m p.payload.update)
::
::  +get-zigs-asset-id:
::    return the ZIGs asset id held by `who`
::
++  get-zigs-asset-id
  |=  who=@p
  =/  m  (strand ,@ux)
  ^-  form:m
  =*  address=@ta
    (scot %ux (~(got by ship-to-address) who))
  ;<  account-update=wallet-update:w  bind:m
    %+  send-pyro-scry:zig-threads  who
    :^  wallet-update:w  %gx  %wallet
    /account/[address]/(scot %ux town-id)/noun/noun
  ?>  ?=(%account -.account-update)
  (pure:m zigs.caller.account-update)
::
::  +get-zigs-asset:
::    return the ZIGs asset held by `who`
::
++  get-zigs-asset
  |=  who=@p
  =/  m  (strand ,asset:w)
  ^-  form:m
  =*  address=@ta
    (scot %ux (~(got by ship-to-address) who))
  ;<  zigs-asset-id=@ux  bind:m  (get-zigs-asset-id who)
  ;<  asset-update=wallet-update:w  bind:m
    %+  send-pyro-scry:zig-threads  who
    :^  wallet-update:w  %gx  %wallet
    /asset/[address]/(scot %ux zigs-asset-id)/noun/noun
  ?>  ?=(%asset -.asset-update)
  (pure:m +.asset-update)
::
++  ted
  ^-  thread:spider
  |=  args-vase=vase
  ^-  form:m
  =/  args  !<((unit arg-mold) args-vase)
  ?~  args
    ~&  >>>  "Usage:"
    ~&  >>>  "-zig!ziggurat-send-zigs-from-bud-to-wes project-name=@t desk-name=@tas request-id=(unit @t)"
    (pure:m !>(~))
  =.  project-name  project-name.u.args
  =.  desk-name     desk-name.u.args
  =*  request-id    request-id.u.args
  ;<  new-ship-to-address=(map @p @ux)  bind:m
    get-ship-to-address
  =.  ship-to-address  new-ship-to-address
  ::
  ::  snapshot initial state: to be restored at end of thread
  ::
  ;<  ~  bind:m
    %+  take-snapshot:zig-threads  snapshot-path
    ~[~nec ~bud ~wes]
  ::
  ::  get initial ZIGs assets held by each involved party
  ::
  ;<  initial-sequencer-zigs=asset:w  bind:m
    (get-zigs-asset sequencer-host)
  ;<  initial-from-zigs=asset:w  bind:m
    (get-zigs-asset from)
  ;<  initial-to-zigs=asset:w  bind:m  (get-zigs-asset to)
  ::
  ::  send tokens:
  ::  +send-wallet-transaction handles submitting the wallet
  ::  transaction and initiating the new sequencer batch
  ::
  ;<  item=@ux  bind:m  (get-zigs-asset-id from)
  ;<  empty-vase=vase  bind:m
    %-  send-wallet-transaction:zig-threads
    :^  from  sequencer-host
      !>(send-discrete-pyro-poke-then-sleep:zig-threads)
    :-  ~s5
    :^  from  from  %uqbar
    :-  %wallet-poke
    !>  ^-  wallet-poke:w
    :*  %transaction
        origin=~
        from=(~(got by ship-to-address) from)
        contract=zigs-contract-address
        town=town-id
    ::
        :^  %give  to=(~(got by ship-to-address) to)
        amount=send-amount  item=item
    ==
  ::
  ::  get final ZIGs assets held by each involved party
  ::
  ;<  final-sequencer-zigs=asset:w  bind:m
    (get-zigs-asset sequencer-host)
  ;<  final-from-zigs=asset:w  bind:m  (get-zigs-asset from)
  ;<  final-to-zigs=asset:w  bind:m    (get-zigs-asset to)
  ::
  ::  determine if transaction went as expected, namely:
  ::  1. `to` has an additional `send-amount` ZIGs
  ::  2. `sequencer-host` has some additional ZIGs: `gas-fee`
  ::  3. `from` has `(add gas-fee send-amount)` less ZIGs:
  ::     the sum of the gas fee and the amount sent
  ::
  ?>  ?=(%token -.initial-sequencer-zigs)
  ?>  ?=(%token -.initial-from-zigs)
  ?>  ?=(%token -.initial-to-zigs)
  ?>  ?=(%token -.final-sequencer-zigs)
  =*  gas-fee=@ud
    %+  sub  balance.final-sequencer-zigs
    balance.initial-sequencer-zigs
  =/  is-from-result-expected=?
    %+  is-equal:expect:zig-threads  final-from-zigs
    %=  initial-from-zigs
        balance
      %+  sub  balance.initial-from-zigs
      (add gas-fee send-amount)
    ==
  =/  is-to-result-expected=?
    %+  is-equal:expect:zig-threads  final-to-zigs
    %=  initial-to-zigs
      balance  (add send-amount balance.initial-to-zigs)
    ==
  ::
  ::  restore initial snapshot state
  ::
  ;<  ~  bind:m  (load-snapshot:zig-threads snapshot-path)
  ::
  ::  return unexpected state if results are not as expected 
  ::
  %-  pure:m
  !>  ^-  (each ~ @t)
  ?:  &(is-from-result-expected is-to-result-expected)
    [%.y ~]
  :-  %.n
  %-  crip
  """
  unexpected result: initial vs final zigs balances:
  send-amount: {<send-amount>}
  gas-fee: {<gas-fee>}
  sequencer:
    {<initial-sequencer-zigs>}
    {<final-sequencer-zigs>}
  from:
    {<initial-from-zigs>}
    {<final-from-zigs>}
  to:
    {<initial-to-zigs>}
    {<final-to-zigs>}
  """
--
