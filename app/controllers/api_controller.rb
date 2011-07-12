class ApiController < ApplicationController

	before_filter :init_sdb, :except => :test
	around_filter :catch_exception


	def test
		render :json => 'OK'
	end




	#
	# params: none
	# returns array
	def list_domains
		render :json => @sdb.list_domains()[:domains]
	end







	#
	# params: 
	#   domain - (string) simpledb domain name
	#   where_clause - (string) the where clause (ex: name LIKE 'John%')
	#
	# returns array of hashes
	# item { name: 'item_name',
	#				 attrs: [ { name: 'attr_name', values: [ 'value1', 'value2' ]}, ...  ]
	def select
		sdbDomainName = URI.decode(params[:domain])
		sqlWhereClause = params[:where_clause];

		sqlString = "select * from " + sdbDomainName

		if( ! sqlWhereClause.nil?)
			sqlString += " where " + URI.decode(sqlWhereClause)
		end

		logger.info("sql: " + sqlString)

		items_arr = Array.new

		@sdb.select(sqlString)[:items].each do |item|
			item.each do |itemName, itemAttrs_hash|

				item_hash = Hash.new

				item_hash[:name] = itemName

				itemAttrs = Array.new
				item_hash[:attrs] = itemAttrs

				itemAttrs_hash.each do |attrName,attrValues_arr|

					attr_hash = Hash.new

					attr_hash[:name] = attrName
					attr_hash[:values] = attrValues_arr

					itemAttrs.push(attr_hash)
				end

				items_arr.push(item_hash)
			end
		end

		render :json => items_arr
	end







	def delete_attributes
		sdbDomainName = params[:domain]
		sdbItemName = params[:item]

		sdbParamAttrs = Hash.new


		params.each do |paramKey,paramValue|

			if(m = paramKey.match(/attr\.(\d)\.(name|value)/))

				case m[2]
					when 'name'
						sdbParamAttrs[m[1]] = Hash.new
						sdbParamAttrs[m[1]][:name] = paramValue
					when 'value'
						sdbParamAttrs[m[1]][:value] = paramValue
				end

			end

		end

		logger.debug sdbParamAttrs.inspect

		sdbAttrs = Hash.new
		sdbParamAttrs.each_key do |key|
			pAttr = sdbParamAttrs[key]
			pAttrName = pAttr[:name]
			sdbAttrs[pAttrName] = Array.new
			if(pAttrValue = pAttr[:value])
				sdbAttrs[pAttrName] << pAttrValue
			end
		end

		res = @sdb.delete_attributes(sdbDomainName, sdbItemName, sdbAttrs)

		render :json => res
	end




	private # =====================




	def init_sdb
		@sdb = RightAws::SdbInterface.new(params[:aws_access_key], params[:aws_secret_key],
										  {
												  :api_version => '2009-04-15'
										  })
	end



	def catch_exception
    	yield
 		rescue Exception => e
			logger.debug "Caught exception! #{e}"
			render :text => e.message.to_s, :status => 500
  		return false
	end

end
