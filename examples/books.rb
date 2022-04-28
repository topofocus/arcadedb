=begin
Books Example

There are several Books. And there is a Table with Keywords. These are our Vertex-Classes

The Keywords are associated to the books, this is realized via an Edge »has_content«

This Example demonstrates how create a simple graph:

Book --> HasContent --> KeyWord

and to query it dynamically using Arcade::Query

There are 3 default search items provided. They are used if no parameter is given.
However, any parameter given is transmitted as serach-criteria, ie.
  ruby books.rb Juli August
defines two search criteria.

=end
require 'bundler/setup'
require 'yaml'
require 'zeitwerk'
require 'arcade'

include Arcade
## require modelfiles
loader =  Zeitwerk::Loader.new
loader.push_dir ("#{__dir__}/../spec/model")
loader.setup

   # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
	 #################  read samples  ##############
	 def read_samples
		 print "\n === READ SAMPLES === \n"
		 ## Lambda fill databasea
		 # Anaylse a sentence
		 # Split into words and upsert them to Word-Class.
		 # The Block is only performed, if a new Word is inserted. 
		 fill_database = ->(sentence, this_book ) do

			 sentence.split(' ').map do | word |
				 this_book.assign  vertex: Ex::Keyword.create( item: word ), via: Ex::HasContent if Ex::Keyword.where( item: word ).empty?
			 end

		 end
		 ## Lambda end
		 words = 'Die Geschäfte in der Industrie im wichtigen US-Bundesstaat New York sind im August so schlecht gelaufen wie seit mehr als sechs Jahren nicht mehr Der entsprechende Empire-State-Index fiel überraschend von plus  Punkten im Juli auf minus 14,92 Zähler Dies teilte die New Yorker Notenbank Fed heute mit. Bei Werten im positiven Bereich signalisiert das Barometer ein Wachstum Ökonomen hatten eigentlich mit einem Anstieg auf 5,0 Punkte gerechnet'
		 this_book =  Ex::Book.create title: 'first'
		 fill_database[ words, this_book ]

		 words2 = 'Das Bruttoinlandsprodukt BIP in Japan ist im zweiten Quartal mit einer aufs Jahr hochgerechneten Rate von Prozent geschrumpft Zu Jahresbeginn war die nach den USA und China drittgrößte Volkswirtschaft der Welt noch um  Prozent gewachsen Der Schwächeanfall wird auch als Rückschlag für Ministerpräsident Shinzo Abe gewertet der das Land mit einem Mix aus billigem Geld und Konjunkturprogramm aus der Flaute bringen will Allerdings wirkte sich die heutige Veröffentlichung auf die Märkten nur wenig aus da Ökonomen mit einem schwächeren zweiten Quartal gerechnet hatten'
		 this_book =  Ex::Book.create title: 'second'
		 fill_database[ words2, this_book ]
		 puts "#{Ex::Keyword.count} keywords inserted into Database"
	 end

   # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
	 #################  display books ##############
	 def display_books_with *desired_words
		 ## Each serach criteria becomes a subquery
		 ## This is integrated into the main_query using 'let'.
		 ## Subquery:  let ${a-y} = select expand(in('has_content')) from keyword where item = {search_word}
		 ## combine with intercect: $z =  Intercect( $a ... $y )
		 ##  Main Query is just
		 ##  select expand( $z )  followed by all let-statements and finalized by "intercect"
		 #

		  # lambda to create subqueries
      word_query = -> (arg) do
				 q= Ex::Keyword.query  where: arg
         q.nodes :in, via: Ex::HasContent
			end

			## We just create "select expand($z)"
      ## without 'expand' the result is "$z" -> "in(ex_has_content)"-> [ book-record ]
      ## with 'expand'  its                     "in(ex_has_content)"-> [ book-record ]
      main_query =  Arcade::Query.new
			main_query.expand( '$z' )


		 print("\n === display_books_with » #{ desired_words.join "," } « === \n")

		 intersects = Array.new
		 ## Now, add subqueries to the main-query
		 desired_words.each_with_index do | word, i |
			 symbol = ( i+97 ).chr   #  convert 1 -> 'a', 2 -> 'b' ...
			 main_query.let   symbol =>  word_query[ item: word  ]
			 intersects << "$#{symbol}"
		 end
		 ## Finally add the intersects statement
     ## Use UnionAll for an superposition  of  positive seraches
     ## Use Intercept for a positive search only if all parameters apply to one book.
     #
		 main_query.let   "$z = unionall(#{intersects.join(', ')}) "
		 #main_query.let   "$z = Intersect(#{intersects.join(', ')}) "
		 puts "generated Query:"
		 puts main_query.to_s
		 puts "\n\n\n"
     result = main_query.query.select_result(:"in(ex_has_content)")
		 puts '-' * 23
		 puts "found books: "
		 puts result.map( &:title ).uniq.join("; ")
		 if result.empty?
			 puts " -- None -- "
			 puts " try » ruby books.rb Japan Flaute «  for a positive search in one of the two sentences"
		 else
			 puts '-_' * 23
			 puts "that's it folks"
		 end
	 end

 if $0 == __FILE__

	 search_items =  ARGV.empty? ? ['China', 'aus', 'Flaute'] : ARGV

       ## clear test database

       databases =  Arcade::Api.databases
       if  databases.include?(Arcade::Config.database[:test])
         Arcade::Api.drop_database Arcade::Config.database[:test]
       end
       Arcade::Api.create_database Arcade::Config.database[:test]

       ## Universal Database handle
       DB = Arcade::Init.connect 'test'
       ## clear test database

       databases =  Arcade::Api.databases
       if  databases.include?(Arcade::Config.database[:test])
         Arcade::Api.drop_database Arcade::Config.database[:test]
       end
       Arcade::Api.create_database Arcade::Config.database[:test]

       ## Universal Database handle
       DB = Arcade::Init.connect 'test'
       print "\n === REBUILD  finished=== \n"
	## check wether the database tables exist. Then delete Database-Class and preallocated ruby-Object
       print " creating Book and  Keyword as Vertex; HasContent as Edge \n"
       Ex::Book.create_type
       Ex::Keyword.create_type
       Ex::HasContent.create_type
       print "\n === PROPERTY === \n"

	 # search_items =  ARGV.empty? ? ['China', 'aus', 'Flaute'] : ARGV

       read_samples
       display_books_with *search_items

 end
