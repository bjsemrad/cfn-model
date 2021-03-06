require 'set'

class ReferenceValidator
  def unresolved_references(cloudformation_hash)
    if cloudformation_hash['Parameters'].nil?
      parameter_keys = []
    else
      parameter_keys = cloudformation_hash['Parameters'].keys
    end

    resource_keys = cloudformation_hash['Resources'].keys
    missing_refs = all_references(cloudformation_hash) - Set.new(parameter_keys + resource_keys)
    missing_refs
  end

  private

  def all_references(cloudformation_hash)
    result = Set.new
    cloudformation_hash['Resources'].values.each do |resource_hash|
      result |= all_ref(resource_hash['Properties'])
      result |= all_get_att(resource_hash['Properties'])
    end
    result
  end

  def all_ref(properties_hash)
    refs = Set.new

    unless properties_hash.nil?
      properties_hash.values.each do |value|
        if value.is_a? Hash
          sub_hash = value

          if sub_hash.size == 1 && !sub_hash['Ref'].nil?
            unless sub_hash['Ref'].is_a? String
              raise ParserError.new("Ref target must be string literal: #{sub_hash}")
            end

            unless pseudo_reference?(sub_hash['Ref'])
              refs << sub_hash['Ref']
            end
          else
            refs |= all_ref(sub_hash)
          end
        end
      end
    end
    refs
  end

  def all_get_att(properties_hash)
    refs = Set.new

    unless properties_hash.nil?
      properties_hash.values.each do |value|
        if value.is_a? Hash
          sub_hash = value

          # ! GetAtt too
          if sub_hash.size == 1 && !sub_hash['Fn::GetAtt'].nil?
            if sub_hash['Fn::GetAtt'].is_a? Array
              refs << sub_hash['Fn::GetAtt'][0]
            elsif sub_hash['Fn::GetAtt'].is_a? String
              if sub_hash['Fn::GetAtt'] =~ /([^.]*)\.(.*)/
                refs << $1
              end

            end
          else
            refs |= all_get_att(sub_hash)
          end
        end
      end
    end

    refs
  end

  def pseudo_reference?(ref)
    ref =~ /AWS::.*/
  end
end
