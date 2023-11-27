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
`curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" kafka-connect:8083/connectors/ -d /conf/mysql_config.json`