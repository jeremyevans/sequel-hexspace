require_relative "spec_helper"

# These are tests for expected SQL generation, that use a mock database

describe "Database" do
  before do
    @db = Sequel.connect('mock://spark')
    @db.sqls
  end

  it "#create_table should support :using and :path options" do
    @db.create_table(:parquetTable, :using=>'org.apache.spark.sql.parquet', :options=>{:path=>"/path/to/view.parquet"}) do
      Integer :x
    end
    @db.sqls.must_equal ["CREATE TABLE `parquetTable` (`x` integer) USING org.apache.spark.sql.parquet OPTIONS ('path'='/path/to/view.parquet')"]
  end

  it "#create_view should support :using and :path options" do
    @db.create_view(:parquetTable, :temp=>true, :using=>'org.apache.spark.sql.parquet', :options=>{:path=>"/path/to/view.parquet"})
    @db.sqls.must_equal ["CREATE TEMPORARY VIEW `parquetTable` USING org.apache.spark.sql.parquet OPTIONS ('path'='/path/to/view.parquet')"]
  end
end

describe "Dataset#with" do
  before do
    @db = Sequel.connect('mock://spark')
    @db.sqls
  end

  it "should reorder CTEs to avoid forward references" do
    ds = ds1 = @db[:t3].with(:t1, @db.select(1))
    ds.sql.must_equal "WITH `t1` AS (SELECT 1) SELECT * FROM `t3`"

    ds2 = @db.select(2).union(@db[:t3], :from_self=>false)
    ds = ds.with(:t2, ds2)
    ds.sql.must_equal "WITH `t1` AS (SELECT 1), `t2` AS (SELECT 2 UNION SELECT * FROM `t3`) SELECT * FROM `t3`"

    ds3 =  @db.select(Sequel[3].as(:v)).union(@db[:t1], :from_self=>false)
    ds = ds.with(:t3, ds3)
    ds.sql.must_equal "WITH `t1` AS (SELECT 1), `t3` AS (SELECT 3 AS `v` UNION SELECT * FROM `t1`), `t2` AS (SELECT 2 UNION SELECT * FROM `t3`) SELECT * FROM `t3`"

    ds = ds1.with(:t2, @db[:t4].join(:t3, :c1=>Sequel[:t5][:c2], :c3=>:c4).natural_join(:t10))
    ds.opts[:with].map{|x| x[:name]}.must_equal %i't1 t2'

    ds = ds.with(:t3, @db[:t4, Sequel[:t6].as(:x8)].where(:x=>@db[:t7].select(:y)).select((Sequel[:t8][:x] + :x).as(:y)))
    ds.opts[:with].map{|x| x[:name]}.must_equal %i't1 t3 t2'

    ds = ds.with(:t7, @db.from('t9'))
    ds.opts[:with].map{|x| x[:name]}.must_equal %i't1 t7 t3 t2'

    ds = ds.with(:t4, @db[Sequel[:t7]])
    ds.opts[:with].map{|x| x[:name]}.must_equal %i't1 t7 t4 t3 t2'

    ds = ds.with(:t5, @db[:t1])
    ds.opts[:with].map{|x| x[:name]}.must_equal %i't1 t7 t4 t3 t5 t2'

    ds = ds.with(:t6, @db[:t1])
    ds.opts[:with].map{|x| x[:name]}.must_equal %i't1 t7 t4 t6 t3 t5 t2'

    ds = ds.with(:t8, @db[:t1])
    ds.opts[:with].map{|x| x[:name]}.must_equal %i't1 t7 t4 t6 t8 t3 t5 t2'

    ds = ds.with(:t9, @db[:t1])
    ds.opts[:with].map{|x| x[:name]}.must_equal %i't1 t9 t7 t4 t6 t8 t3 t5 t2'

    ds = ds.with(:t10, @db[:t1])
    ds.opts[:with].map{|x| x[:name]}.must_equal %i't1 t9 t7 t4 t6 t8 t3 t5 t10 t2'

    ds = ds.with(:t11, @db[:t1])
    ds.opts[:with].map{|x| x[:name]}.must_equal %i't1 t9 t7 t4 t6 t8 t3 t5 t10 t2 t11'
  end
end
