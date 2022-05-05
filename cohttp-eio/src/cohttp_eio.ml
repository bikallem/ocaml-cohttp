module Server = struct
  module Reader = Reader
  module Chunk = Chunk
  module Request = Request
  module Response = Response
  include Server
end
