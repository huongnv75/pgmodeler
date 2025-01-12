# Catalog queries for tables
# CAUTION: Do not modify this file unless you know what you are doing.
# Code generation can be broken if incorrect changes are made.

%if {list} %then
	%if {use-signature} %then
		%set {signature} [ ns.nspname || '.' || ]
	%end

	[ SELECT tb.oid, tb.relname AS name, ns.nspname AS parent, 'schema' AS parent_type
	FROM pg_class AS tb
	LEFT JOIN pg_namespace AS ns ON ns.oid=tb.relnamespace ]

	%if {schema} %then
		[ WHERE tb.relkind IN ('r','p') AND ns.nspname= ] '{schema}'
	%else
		[ WHERE tb.relkind IN ('r','p')]
	%end

	%if {last-sys-oid} %then
		[ AND tb.oid ] {oid-filter-op} $sp {last-sys-oid}
	%end

	%if {not-ext-object} %then
		[ AND ] ( {not-ext-object} )
	%end

	%if {name-filter} %then
		[ AND ] ( {signature} [ tb.relname ~* ] E'{name-filter}' )
	%end
%else
	%if {attribs} %then
		[SELECT tb.oid, tb.relname AS name, tb.relnamespace AS schema, tb.relowner AS owner,
		tb.reltablespace AS tablespace, tb.relacl AS permission, ]

		%if ({pgsql-ver} <f "12.0") %then
			[ relhasoids AS oids_bool, ]
		%else
			[ FALSE AS oids_bool, ]
		%end

		[ CASE relpersistence
			WHEN 'u' THEN TRUE
			ELSE FALSE
		END
		AS unlogged_bool, 
		tb.relrowsecurity AS rls_enabled_bool, 
		tb.relforcerowsecurity AS rls_forced_bool, 

		(SELECT array_agg(inhparent) AS parents FROM pg_inherits WHERE inhrelid = tb.oid 
 		 AND inhparent NOT IN (SELECT partrelid FROM pg_partitioned_table)),

		 CASE relkind
			WHEN 'p' THEN TRUE
			ELSE FALSE
			END AS is_partitioned_bool,

			CASE relispartition
			WHEN TRUE THEN
			(SELECT inhparent FROM pg_inherits WHERE inhrelid = tb.oid)
			ELSE
			NULL
		END AS partitioned_table,
		pg_get_expr(relpartbound, tb.oid) AS partition_bound_expr, 	]

		({comment}) [ AS comment ]

		[ , st.n_tup_ins AS tuples_ins, st.n_tup_upd AS tuples_upd, st.n_tup_del AS tuples_del, st.n_live_tup AS row_amount,
		st.n_dead_tup AS dead_rows_amount, st.last_vacuum, st.last_autovacuum, st.last_analyze, ]

		[ CASE partstrat
			WHEN 'l' then 'LIST'
			WHEN 'r' then 'RANGE'
			WHEN 'h' then 'HASH'
			ELSE NULL
		END AS partitioning,
		pg_get_expr(partexprs, partrelid) AS part_key_exprs,
		partattrs::oid] $ob $cb [ AS part_key_cols,
		partclass::oid] $ob $cb [ AS part_key_opcls,
		partcollation::oid] $ob $cb [ AS part_key_colls ]

		[ FROM pg_class AS tb
		LEFT JOIN pg_tables AS _tb1 ON _tb1.tablename=tb.relname
		LEFT JOIN pg_stat_all_tables AS st ON st.relid=tb.oid 
		LEFT JOIN pg_partitioned_table AS pt ON pt.partrelid = tb.oid 
		WHERE tb.relkind IN ('r','p') ]

		%if {last-sys-oid} %then
			[ AND tb.oid ] {oid-filter-op} $sp {last-sys-oid}
		%end

		%if {not-ext-object} %then
			[ AND ] ( {not-ext-object} )
		%end

		%if {filter-oids} %or {schema} %then
			[ AND ]

			%if {filter-oids} %then
				[ tb.oid IN (] {filter-oids} )

				%if {schema} %then
					[ AND ]
				%end
			%end

			%if {schema} %then
				[ _tb1.schemaname= ] '{schema}'
			%end
		%end
	%end
%end
