````
curl -XPOST -H 'Content-type:application/json''localhost:8083/connectors' -d '{  
	"name" : "second_es_sink",  
	"config" : {  
	"connector.class":"io.confluent.connect.elasticsearch.ElasticsearchSinkConnector",  "tasks.max" : "1",  
	"topics" : "logs",  
	"topic.index.map" : "logs:logs_index",  
	"connection.url" : "http://localhost:9200",  
	"type.name" : "true",  
	"key.ignore" : "true",  
	"schema.ignore" : "true"  
	}  
}'
````


Lancer un connecteur à partir d'un fichier :
`url -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @connect_datagen_rating.json`