require 'nokogiri'
require "solr_config_comparator/version"

module SolrConfigComparator
  class Schema
    ALL_KNOWN_ELEMENTS = [
      "copyField",
      "defaultSearchField",
      "dynamicField",
      "field",
      "fieldType",
      "solrQueryParser",
      "uniqueKey",
    ]

    def self.compare(expected_schema, reported_schema)
      new(expected_schema, reported_schema).compare
    end

    def initialize(expected_schema, reported_schema)
      @expected_schema = Nokogiri::XML.parse(expected_schema)
      @reported_schema = Nokogiri::XML.parse(reported_schema)
    end

    attr_reader :expected_schema, :reported_schema

    # truthy response means there was an issue
    def compare
      catch { |reason_tag|
        ! nodes_deep_equal(@expected_schema.root, @reported_schema.root, reason_tag)
      }
    end

    def nodes_deep_equal(nodeA, nodeB, reason_tag=nil)
      nodeA.attributes.each_pair do |attribute_name, a_attr|
        unless nodeB[attribute_name] == a_attr.value
          return false unless reason_tag
          throw reason_tag, "attribute `#{attribute_name}` differs in between #{nodeA} and #{nodeB}"
        end
      end
      a_children = sort_children(nodeA.xpath('*'))
      b_children = sort_children(nodeB.xpath('*'))
      binding.pry
      if a_children.length != b_children.length
        return false unless reason_tag
        throw reason_tag, "different number of child nodes between #{nodeA} and #{nodeB}"
      end
      a_children.zip(b_children).all? { |a,b| nodes_deep_equal(a, b, reason_tag) }
    end

    def sort_children(nodes)
      nodes.sort_by { |node|
        cmp = comparator_for_element_name(node.name) or binding.pry
        [node.name, cmp.call(node)]
      }
    end


    def comparator_for_element_name(element_name)
      @comparator_for_element_name ||= Hash.new.tap { |hash|
        name_cmp = lambda { |node| node.attribute('name').value }
        noop_cmp = lambda { |node| true }
        copy_field_cmp = lambda { |node| [node['source'], node['dest']] }
        hash.default_proc = proc { |h, k| lambda { |node| node } }

        hash.update(
          'dynamicField' => name_cmp,
          'field' => name_cmp,
          'fieldType' => name_cmp,
          'uniqueKey' => noop_cmp,
          'defaultSearchField' => noop_cmp,
          'solrQueryParser' => noop_cmp,
          'copyField' => copy_field_cmp,
        )
      }

      @comparator_for_element_name[element_name]
    end
  end
end
