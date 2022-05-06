module Reader = Reader

module Server = struct
  module Chunk = Chunk
  module Request = Request
  module Response = Response
  include Server
end
