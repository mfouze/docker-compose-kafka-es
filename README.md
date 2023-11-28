
Lancer un connecteur

* Aller dans le dossier config connect config
  `cd connect_config`
* Lancer le connecteur
  ` url -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @connect_es_sink.json`