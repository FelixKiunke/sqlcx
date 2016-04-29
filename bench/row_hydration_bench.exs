defmodule RowHydrationBench do
  use Benchfella

  @types [:INTEGER, :"varchar(255)", :datetime, :datetime, :"varchar(255)"]
  @columns [:id, :name, :created_at, :updated_at, :type]
  @rows [{1, "Mikey", "2012-10-14 05:46:28.318107", "2013-09-06 22:29:36.610911", :undefined},
   {2, "jon", "2012-10-14 05:46:28.321310", "2012-10-14 05:46:28.321310", :undefined},
   {3, "matte", "2012-10-14 05:46:35.762348", "2012-10-14 05:46:35.762348", :undefined},
   {4, "mattd", "2012-10-14 05:46:35.765167", "2012-10-14 05:46:35.765167", :undefined},
   {5, "bry", "2012-10-14 05:46:35.767830", "2012-10-14 05:46:35.767830", :undefined},
   {6, "jated", "2012-10-14 05:46:35.769930", "2012-10-14 05:46:35.769930", :undefined},
   {7, "brnt", "2012-10-14 05:46:35.772602", "2012-10-14 05:46:35.772602", :undefined},
   {8, "lane", "2012-10-14 05:47:13.077601", "2012-10-14 05:47:13.077601", :undefined},
   {9, "cathy", "2012-10-15 14:35:25.031584", "2012-10-15 14:35:25.031584", :undefined},
   {10, "sarah", "2012-10-15 14:35:25.035501", "2012-10-15 14:35:25.035501", :undefined},
   {11, "paul", "2012-10-15 14:35:27.930982", "2012-10-15 14:35:27.930982", :undefined},
   {12, "ny", "2012-10-15 14:35:27.967000", "2012-10-15 14:35:27.967000", :undefined},
   {13, "mike corrigan", "2012-10-15 14:35:27.969733", "2012-10-15 14:35:27.969733", :undefined},
   {14, "gp", "2012-10-15 14:35:27.971940", "2012-10-15 14:35:27.971940", :undefined},
   {15, "derek", "2012-10-15 14:35:27.974134", "2012-10-15 14:35:27.974134", :undefined},
   {16, "chris", "2012-10-15 14:35:27.976243", "2012-10-15 14:35:27.976243", :undefined},
   {17, "sloan", "2012-10-15 14:35:50.441170", "2012-10-15 14:35:50.441170", :undefined},
   {18, "duane", "2012-10-15 14:35:53.796919", "2012-10-15 14:35:53.796919", :undefined},
   {19, "ben", "2012-10-15 14:35:53.800582", "2012-10-15 14:35:53.800582", :undefined},
   {20, "russell", "2012-10-15 14:35:58.065161", "2012-10-15 14:35:58.065161", :undefined},
   {21, "jared cook", "2013-05-12 03:17:01.500997", "2013-05-12 03:17:01.500997", :undefined},
   {22, "chris hopkins", "2013-05-31 20:38:10.508409", "2013-05-31 20:38:10.508409", :undefined},
   {23, "nate priego", "2013-08-23 23:21:42.697119", "2013-08-23 23:21:42.697119", :undefined},
   {24, "Neil DeGrasse Tyson", "2013-08-30 22:58:52.945124", "2013-09-06 22:29:09.872678", "Team"},
   {25, "Slothstronauts", "2013-08-30 22:58:52.947709", "2013-09-06 22:27:17.820250", "Team"},
   {26, "Ny and Chris", "2013-08-30 22:58:52.950786", "2013-09-06 22:30:25.684407", "Team"}]

  bench "hydrate keyword list rows" do
    Sqlcx.Row.from(@types, @columns, @rows, [])
  end

  bench "hydrate map rows" do
    Sqlcx.Row.from(@types, @columns, @rows, %{})
  end
end
