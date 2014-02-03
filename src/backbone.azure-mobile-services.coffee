do ->
	Backbone.AzureModel = Backbone.Model.extend
		methodUrl:
			read: ->
				for index in @indices
					if (@get index)?
						return "?$filter=#{index} eq '#{@get index}'"

		indices: ['id']
		ignored: ->
			['token']

		save: (attributes = {}, options = {}) ->
			options.patch = true if not @isNew() #azure only does patch requests
			_.extend attributes, @attributes
			_.each @attributes, (value, key) =>
				delete attributes[key] if _.isFunction(value) or _.contains(@ignored(), key)
				if isReference(@attributes[key])
					attributes[key] = JSON.stringify(prepareRef.call(@, prepareRef(@attributes[key])))
				else if _.isArray(@attributes[key]) and _.reduce(@attributes[key], ((m, val) -> isReference(val) and m), true)
					attributes[key] = JSON.stringify (for ref in @attributes[key] then prepareRef.call(@, ref))
			Backbone.Model::save.call(@, attributes, options)

		sync: (method, model, options) ->
			if model.methodUrl and model.methodUrl[method]
				options = options or {}
				options.url = model.urlRoot + model.methodUrl[method].call(@)
			Backbone.sync method, model, addAzureCredentials(options)

		parse: (response) ->
			response = response[0] if $.isArray(response)
			_.each response, (value, key) ->
				try
					ref = JSON.parse value #convert references to models
					if isReference(ref)
						response[key] = new Schema[ref.className].Model(ref.attributes) if isReference(ref)
					else if _.isArray(ref) and _.reduce(ref, ((memo, val) -> isReference(val) and memo), true)
						response[key] = for data in ref then new Schema[ref.className].Model(ref.attributes)
				catch error #not a reference
			response

	Backbone.AzureCollection = Backbone.Collection.extend
		sync: (method, model, options) ->
			Backbone.sync method, model, addAzureCredentials(options)

	isReference = (obj) ->
		obj?.className? and obj?.attributes?

	prepareRef = (obj) ->
		res = {}
		res = obj.attributes
		_.each res.attributes, (value, key) => delete res.attributes[key] if _.isFunction(value) or _.contains(@ignored(), key) or isReference(value)
		res.className = obj.className
		res

	addAzureCredentials = (options) ->
		options.beforeSend = (xhr) ->
			xhr.setRequestHeader 'X-ZUMO-APPLICATION', App.apiKey
			xhr.setRequestHeader 'X-ZUMO-AUTH', App.request('user:current').get('token') if App.request('user:current')
		options