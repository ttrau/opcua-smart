class BaseNode
  def self.to_s() return self.NodeId.to_s end
  def self.from_xml(server, xml, namespace_indices, local_namespaces)
    local_nodeid = NodeId.from_string(xml.find("@NodeId").first.to_s)
    namespace_index = namespace_indices[local_nodeid.ns]
    namespace = local_namespaces[local_nodeid.ns]
    nodeid = NodeId.new(server.namespaces.index(local_namespaces[local_nodeid.ns]), local_nodeid.id, local_nodeid.type)
    local_browsename = QualifiedName.from_string(xml.find("@BrowseName").first.to_s)
    browsename = QualifiedName.new(server.namespaces.index(local_namespaces[local_browsename.ns]), local_browsename.name)
    displayname = LocalizedText.parse xml.find("*[name()='DisplayName']").first
    description = LocalizedText.parse xml.find("*[name()='Description']").first
    nodeclass = NodeClass.const_get(xml.find("name()")[2..-1])

    if xml.find("@SymbolicName").first
      constant_name = xml.find("@SymbolicName").first.to_s
    elsif
      constant_name = browsename.name
    end

    unless namespace_index.to_s.equal? ""
      unless Object.const_defined?(namespace_index)
        Object.const_set(namespace_index, Module.new)
      end
      basenode = Class.new(BaseNode)
      Object.const_get(namespace_index).const_set(constant_name, basenode)
    end

    basenode.define_singleton_method(:NodeId, -> { return nodeid })
    basenode.define_singleton_method(:BrowseName, -> { return browsename })
    basenode.define_singleton_method(:DisplayName, -> { return displayname })
    basenode.define_singleton_method(:Description, -> { return description })
    basenode.define_singleton_method(:NodeClass, -> { return nodeclass })
    basenode.define_singleton_method(:Namespace, -> { return namespace })

    xml.find("@*").each do |a|
      if(a.qname == "NodeId" || a.qname == "BrowseName")
        # already done
      elsif a.qname.equal? "ParentNodeId"
        parent_local_nodeid = NodeId.from_string(a)
        parent_nodeid = NodeId.new(server.namespaces[0].index(local_namespaces[parent_local_nodeid.ns]), parent_local_nodeid.id, parent_local_nodeid.type)
        basenode.define_singleton_method(a.qname.to_sym, -> { return parent_nodeid })
      elsif a.equal? "true"
        basenode.define_singleton_method(a.qname.to_sym, -> { return true })
      elsif a.equal? "false"
        basenode.define_singleton_method(a.qname.to_sym, -> { return false })
      else
        basenode.define_singleton_method(a.qname.to_sym, -> { return a })
      end
    end

    if nodeclass.equal? NodeClass::ReferenceType
      inversename = xml.find("*[name()='InverseName']/text()").first.to_s || nil
      basenode.define_singleton_method(:InverseName, -> { return inversename })
    end

    basenode
  end
end

class NodeId
  def ns() @ns end
  def id() @id end
  def type() @type end
  def to_s() 
    nodeid_type = "i"
    if id.equal? 3
      nodeid_type = "s"
    end
    "ns=#{ns};#{nodeid_type}=#{id}"
  end
  def initialize(namespaceindex, identifier, identifiertype=NodeIdType::String) 
    unless(namespaceindex.is_a?(Integer) || namespaceindex >= 0)
      raise "Bad namespaceindex #{namespaceindex}" 
    end
    if (identifier =~ /\A[-+]?[0-9]+\z/) && identifier.to_i > 0
      identifier = identifier.to_i
      identifiertype = NodeIdType::Numeric
    end
    @ns = namespaceindex
    @id = identifier
    @type = identifiertype
  end
  def self.from_string(nodeid)
    if nodeid.match /ns=(.*?);/
      ns = nodeid.match(/ns=(.*?);/)[1].to_i
      type = nodeid.match(/;(.)=/)[1]
      id = nodeid.match(/;.=(.*)/)[1]
    else
      ns = 0
      type = nodeid.match(/(.)=/)[1]
      id = nodeid.match(/.=(.*)/)[1]
    end
    if type.equal? "i"
      nodeid_type = NodeIdType::Numeric
    elsif type.equal? "s"
      nodeid_type = NodeIdType::String
    end
    NodeId.new(ns, id, nodeid_type)
  end
end

class QualifiedName
  def ns() @ns end
  def name() @name end
  def to_s() "#{ns}:#{name}" end
  def initialize(namespaceindex, name) 
    unless(namespaceindex.is_a?(Integer) || namespaceindex >= 0)
      raise "Bad namespaceindex #{namespaceindex}" 
    end
    @ns = namespaceindex
    @name = name
  end
  def self.from_string(qualifiedname)
    if qualifiedname.include? ":"
      ns = qualifiedname.match(/^([^:]+):/)[1].to_i
      name = qualifiedname.match(/:(.*)/)[1]
    else
      ns = 0
      name = qualifiedname
    end
    QualifiedName.new(ns, name)
  end
end

class LocalizedText
  def locale() @locale end
  def text() @text end
  def to_s()
    if locale == ""
      return text
    else
      return "#{locale}:#{text}"
    end
  end
  def initialize(text, locale="")
    if text == ""
      return nil
    end
    @locale = locale
    @text = text
  end
  def self.from_string(localizedtext)
    locale = localizedtext.match(/^([^:]+):/)[1]
    text = localizedtext.match(/:(.*)/)[1]
    LocalizedText.new(text, locale)
  end
  def self.parse(xml_element)
    if(xml_element.nil?)
      return nil
    end
    text = xml_element.to_s || ""
    locale = xml_element.find("@Locale").first.to_s || ""
    LocalizedText.new(text, locale)
  end
end

##
# NodeClasses see https://documentation.unified-automation.com/uasdkhp/1.0.0/html/_l2_ua_node_classes.html
class NodeClass
  Unspecified = 0
  Object = 1
  Variable = 2
  Method = 4
  ObjectType = 8
  VariableType = 16
  ReferenceType = 32
  DataType = 64
  View = 128
end

class NodeIdType
  Numeric = 0
  String = 3
end