module Bus
  def self.routes(service_ids)
    ActiveRecord::Base.connection.select_all("select case when routes.short_name = ' ' then 'Other' else routes.short_name end route_short_name, trips.headsign, count(trips.id) as trips_remaining from routes inner join trips on trips.route_id = routes.id where routes.route_type in (3) and trips.service_id in (#{service_ids.join(',')}) and trips.end_time > '#{Now.time}' group by routes.short_name, trips.headsign").
      group_by {|r| r["route_short_name"]}.
      map {|short_name, values| {:route_short_name => short_name, 
          :headsigns => values.map {|x| [x["headsign"], x["trips_remaining"].to_i] }
        } 
      }.
      sort_by {|x| x[:route_short_name].to_i == 0 ? 10000 : x[:route_short_name].to_i }
  end

  def self.trips(options)
    date = Now.date
    route_short_name = options[:route_short_name]
    headsign = options[:headsign]
    service_ids = Service.active_on(date).map(&:id)
    now = Now.time

    Trip.all(:joins => :route,
             :conditions => ["routes.short_name = ? and headsign = ? and service_id in (?) and end_time > '#{now}'", route_short_name, headsign, service_ids], 
             :order => "start_time asc", 
             :limit => options[:limit] || 10)
  end

  def self.arrivals(stopping_id, options)
    headsign = options[:headsign]
    route_ids = Route.all(:conditions => {:short_name => options[:route_short_name]}).map(&:id)

    Stopping.all(
      :joins => "inner join trips on trips.id = stoppings.trip_id",
      :conditions => ["stoppings.stop_id = ? and trips.route_id in (?) and " + 
        "trips.service_id in (?) and trips.headsign = ? " +
        "and stoppings.arrival_time > '#{Now.time}'", stopping_id, route_ids, Service.ids_active_today, headsign],
      :order => "stoppings.arrival_time asc"
    )
  end
end