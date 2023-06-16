::  send-nft-from-nec-to-bud.hoon:
::  1. send NFT from ~nec to ~bud
::  2. confirm is now held by ~bud and not ~nec after send
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
    eng=zig-engine,
    w=zig-wallet,
    zig=zig-ziggurat
/+  strandio,
    smart=zig-sys-smart,
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
  ~nec
::
++  to
  ^-  @p
  ~bud
::
++  nft-contract-address
  ^-  @ux
  0x6d30.9c3c.0130.12fc.48e9.2877.4e21.a9af.082c.b20a.ceb5.0742.529d.8130.a0e5.1b0f
::
++  item-id
  ^-  @ux
  0xddd8.16fc.a999.3b02.2cc9.9742.7f69.87e6.ec6f.8a53.818f.df26.93e2.763a.93f2.30b1
::
++  snapshot-path
  ^-  path
  /[project-name]/send-nft-from-nec-to-bud/0
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
::  +get-item:
::    return the item, given current chain state
::
++  get-item
  |=  item-id=@ux
  =/  m  (strand ,item:smart)
  ^-  form:m
  ;<  scry-result=(each chain:eng @t)  bind:m
    (send-pyro-chain-scry:zig-threads town-id)
  ?>  ?=(%& -.scry-result)
  (pure:m (got:big:eng p.p.scry-result item-id))
::
++  ted
  ^-  thread:spider
  |=  args-vase=vase
  ^-  form:m
  =/  args  !<((unit arg-mold) args-vase)
  ?~  args
    ~&  >>>  "Usage:"
    ~&  >>>  "-zig!ziggurat-send-nft-from-nec-to-bud project-name=@t desk-name=@tas request-id=(unit @t)"
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
  ::  get initial item state
  ::
  ;<  initial-item=item:smart  bind:m  (get-item item-id)
  ::
  ::  send nft:
  ::  +send-wallet-transaction handles submitting the wallet
  ::  transaction and initiating the new sequencer batch
  ::
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
        contract=nft-contract-address
        town=town-id
    ::
        :+  %give-nft  to=(~(got by ship-to-address) to)
        item=item-id
    ==
  ::
  ::  get final item state
  ::
  ;<  final-item=item:smart  bind:m  (get-item item-id)
  ::
  ::  determine if transaction went as expected, namely:
  ::  1. item was initially owned by ~nec
  ::  2. item is finally owned by ~bud
  ::
  :: ?>  ?=(%nft -.initial-item)
  :: ?>  ?=(%nft -.final-item)
  =/  is-initial-result-expected=?
    %+  tuple-contains:expect:zig-threads
      (~(got by ship-to-address) from)
    initial-item
  =/  is-final-result-expected=?
    %+  tuple-contains:expect:zig-threads
      (~(got by ship-to-address) to)
    final-item
  ::
  ::  restore initial snapshot state
  ::
  ;<  ~  bind:m  (load-snapshot:zig-threads snapshot-path)
  ::
  ::  return unexpected state if results are not as expected
  ::
  %-  pure:m
  !>  ^-  (each ~ @t)
  ?:  &(is-initial-result-expected is-final-result-expected)
    [%.y ~]
  :-  %.n
  %-  crip
  """
  unexpected result: initial vs final nft item:
  sender ({<from>}) id: {<(~(got by ship-to-address) from)>}
  receiver ({<to>}) id: {<(~(got by ship-to-address) to)>}
  initial:
    {<initial-item>}
  final:
    {<final-item>}
  """
--
