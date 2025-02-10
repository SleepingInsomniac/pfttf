module PFTTF
  class Reader
    record TableHeader,
      checksum : UInt32,
      offset : UInt32,
      length : UInt32
  end
end
