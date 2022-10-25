## Setup

```ocaml
# #require "eio.mock";;
# #require "cohttp-eio";;
```

```ocaml
open Eio.Std
open Cohttp_eio
```

```ocaml
# #use "server.ml";;
```

```ocaml
let socket = Eio_mock.Flow.make "socket"
let mock_clock = Eio_mock.Clock.make ();;
Eio_mock.Clock.set_time mock_clock 1666627935.85052109;;
let clock = (mock_clock :> Eio.Time.clock);;
let connection_handler = Server.connection_handler app clock
```

