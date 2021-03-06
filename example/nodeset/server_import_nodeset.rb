#!/usr/bin/ruby
# require 'opcua/server'
require_relative '../../lib/opcua/server'

Daemonite.new do
  on startup do |opts|
    srv = opts['server'] = OPCUA::Server.new

    def err(message)
      puts "\e[31m#{message}\e[0m"
    end
    def highlight(message)
      puts "\e[36m#{message}\e[0m"
    end

    srv.import_ua # import small nodeset --> faster and contains most necessary stuff
    #srv.import_ua_full # import full nodeset

    highlight "Imported OPC UA Nodeset"

    # Tests:
    err "UA::HasSubtype not found" unless UA::HasSubtype.to_s == "ns=0;i=45"
    err "UA::LocalizedText not found" unless UA::LocalizedText.to_s == "ns=0;i=21"

    srv.add_nodeset File.read('Opc.Ua.Di.1.2.NodeSet2.xml'), :DI                               # https://opcfoundation.org/UA/schemas/DI/1.2/Opc.Ua.Di.NodeSet2.xml
    highlight "Imported DI Nodeset"
    srv.add_nodeset File.read('Opc.Ua.AutoID.1.0.NodeSet2.xml'), :AutoId, :DI                  # https://opcfoundation.org/UA/schemas/AutoID/1.0/Opc.Ua.AutoID.NodeSet2.xml
    highlight "Imported AutoID Nodeset"
    srv.add_nodeset File.read('Example.Reference.1.0.NodeSet2.xml'), :Testing, :DI, :Robotics  # Really weird local testing nodeset with references to DI and Robotics
    highlight "Imported Testing Nodeset"
    ex = srv.add_namespace 'http://example.org/'
    
    # Tests:
    err "Server known Nodes: #{srv.nodes.length} changed?" unless srv.nodes.length == 597 || srv.nodes.length == 218 # depends on UA full or tiny
    err "add_object_type Error" unless srv.add_object_type("TestType","ns=#{ex};i=77777", UA::BaseObjectType, UA::HasSubtype).to_s == "ns=#{ex};i=77777"
    err "add_data_type Error" unless srv.add_data_type("TestDataType","ns=#{ex};i=77778", UA::Structure, UA::HasSubtype).to_s == "ns=#{ex};i=77778"
    err "add_object Error" unless srv.add_object("TestDevice", "ns=#{ex};i=31243", srv.objects, UA::Organizes, AutoId::OpticalReaderDeviceType).to_s == "ns=#{ex};i=31243"

    tt = srv.add_object_type(:TestComponentType, "ns=#{ex};i=77900", DI::ComponentType, UA::HasSubtype).tap{ |t|
      t.add_variable :Matrix_2x2
      t.add_variable :Matrix_2x3x2
      t.add_variable :Array
      # ERROR almost always: (Error should have something to do with server_add_object_type)
      #t.add_method :Puts, input1: OPCUA::TYPES::STRING do |node, input1|
      #  highlight input1
      #end
    }
    
    # ERROR sometimes:
    #tt.add_method :Puts, input1: OPCUA::TYPES::STRING do |node, input1|
    #  highlight input1
    #end

    srv.objects.manifest(:MatrixTest, tt)

    v0 = srv.get "ns=#{ex};s=/MatrixTest/Matrix_2x2"
    v1 = srv.get "ns=#{ex};s=/MatrixTest/Matrix_2x3x2"
    v2 = srv.get "ns=#{ex};s=/MatrixTest/Array"

    v0.datatype = UA::Double
    v0.rank = 2 # just as example, will be automatically set when defining a matrix
    v0.dimensions = [2, 2] # 2x2 Matrix
    v0.value = [
      11, 12, 
      21, 22
    ]
    v1.datatype = UA::Double
    v1.rank = 2
    v1.dimensions = [2, 3, 2] # 2x3x2 Matrix
    v1.value = [
      0, 1, 10, 11, 20, 21,
      100, 101, 110, 111, 120, 121
    ] # filling upward from low to high
    #v2.datatype = UA::Double
    #v2.rank = 1
    #v2.dimensions = [4] # don't set this stuff, because it is already defined in the array:
    v2.value = [1, 2, 3, 4]

    err "v0 false DataType" unless v0.datatype.name == "Double"
    err "v0 false ValueRank" unless v0.rank == 2
    err "v0 false Dimensions" unless v0.dimensions == [2, 2]
    err "v0 false Value" unless v0.value[0] == [11, 12, 21, 22]
    err "v1 false ValueRank" unless v1.rank == 3
    err "v1 false Dimensions" unless v1.dimensions == [2, 3, 2]
    err "v1 false Value" unless v1.value[0] == [0, 1, 10, 11, 20, 21, 100, 101, 110, 111, 120, 121]
    err "v2 false DataType at the node itself is not automatically set: #{v2.datatype.name}" unless v2.datatype.name == "Double"
    err "v2 false ValueRank" unless v2.rank == 1
    err "v2 false Dimensions" unless v2.dimensions == [4]
    err "v2 false Value" unless v2.value[0] == [1, 2, 3, 4]
    v2.value = [1, 2, 3, 4, 5, 6, 7, 8, 9]
    err "v2 false Value when changing array size" unless v2.value[0] == [1, 2, 3, 4, 5, 6, 7, 8, 9]


    err "DI import Error @TopologyElement->ComponentType" unless DI::ComponentType.follow_inverse(UA::HasSubtype).first.name == "TopologyElementType"
    err "DI DeviceType not found" unless DI::ComponentType.follow(UA::HasSubtype).select{ |n| n.name == "DeviceType" }.length == 1
    err "UA HasChild references missing or new added" unless UA::HasChild.follow_all(UA::HasSubtype).select{ |n| n.name == "Aggregates" || n.name == "HasSubtype" }.length == 2

    node = UA::HasComponent
    path = ""
    until node.nil?
      path += "->#{node.name}"
      node = node.follow_inverse(UA::HasSubtype).first
    end
    err "Parents of UA::HasComponent false: #{path}" unless path == "->HasComponent->Aggregates->HasChild->HierarchicalReferences->References"









    puts "\e[32mFinished\e[0m"
    
  rescue => e
    puts "=====================ERROR====================="
    puts e.message
    puts e.backtrace
    puts "======================END======================"
  end

  counter = 0
  run do |opts|
    GC.start
    sleep opts['server'].run
    if counter % 40 == 0
      #raise "exit"
    end
    counter += 1
  rescue => e
    if e.message == "exit"
      puts "\n\n\-->exit"
      break
    end
  end
end.loop!

exit