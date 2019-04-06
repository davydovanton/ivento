require 'dry-struct'
require_relative '../lib/ivento'

module Events
  class TaskCreated < Ivento::Event::Base
    payload_attributes(
      id: Types::Integer,
      title: Types::String,
      status: Types::String.enum('open')
    )
  end

  class TaskUpdated < Ivento::Event::Base
    payload_attributes(
      id: Types::Integer,
      title: Types::String,
      status: Types::String.enum('open', 'completed')
    )
  end

  class NotExistedTaskCompleted < Ivento::Event::Base
    payload_attributes(
      id: Types::Integer
    )
  end
end

# Event producer function
#
# Interface:
#   call : event list -> payload -> event list

module Producers
  class CreateTask
    def initialize(project)
      @project = project
    end

    def call(events, payload)
      [Events::TaskCreated.new(payload: { id: payload[:id], title: payload[:title], status: 'open' })]
    end
  end

  class CompleteTask
    def initialize(project)
      @project = project
    end

    def call(events, payload)
      existed_ids = @project.call(Projections::TaskIds.new, {}, events)[:ids]

      if existed_ids.include?(payload[:id])
        [Events::TaskUpdated.new(payload: { id: payload[:id], status: 'completed' })]
      else
        [Events::NotExistedTaskCompleted.new(payload: { id: payload[:id] })]
      end
    end
  end

  class UpdateTaskTitle
    def initialize(project)
      @project = project
    end

    def call(events, payload)
      existed_ids = @project.call(Projections::TaskIds.new, {}, events)[:ids]

      if existed_ids.include?(payload[:id])
        [Events::TaskUpdated.new(payload: { id: payload[:id], title: payload[:title] })]
      else
        [Events::NotExistedTaskCompleted.new(payload: { id: payload[:id] })]
      end
    end
  end
end

# Implementation of Projections (agregators)
#
# Interface for project:
#   call : projection -> base state -> events -> state
#
# Interface for each projection:
#   call : state -> event -> state

module Projections
  class TotalAndCompletedTasks
    def call(state, event)
      case event
      when Events::TaskCreated
        state[:total] = (state[:total] || 0) + 1
      when Events::TaskUpdated
        if event.payload[:status]
          state[:completed] = (state[:completed] || 0) + 1
        end
      end

      state
    end
  end

  class AllTask
    def call(state, event)
      case event
      when Events::TaskCreated
        state[:tasks] ||= []
        state[:tasks] << event.payload
      when Events::TaskUpdated
        completed_task = state[:tasks].select { |task| task[:id] == event.payload[:id] }.first
        completed_task = { **completed_task, **event.payload }

        state[:tasks] = state[:tasks].reject { |task| task[:id] == event.payload[:id] } + [completed_task]
      end

      state
    end
  end

  class TaskTitles
    def call(state, event)
      case event
      when Events::TaskCreated
        state[:titles] ||= []
        state[:titles] << event.payload[:title]
      end

      state
    end
  end

  class TaskIds
    def call(state, event)
      case event
      when Events::TaskCreated
        state[:ids] ||= []
        state[:ids] << event.payload[:id]
      end

      state
    end
  end
end

require_relative '../lib/ivento/event_store/adapters/sql'

# DB = Sequel.connect
#
# DB.create_table :events do
#   String :eid, unique: true, null: false
#   String :event_name, null: false
#
#   String :stream, null: false
#   String :version, null: false
#   DateTime :created_at
#
#   jsonb :payload
# end

Events::NotExistedTaskCompleted.new(version: '1', payload: { id: 1 })

adapter = Ivento::EventStore::Adapters::Sql.new('postgres://localhost/todo_app_event_sourcing')
event_store = Ivento::EventStore.new(adapter)

project = Ivento::Projections::Project.new

task_stream = 'task_stream'

event_store.subscribe(Events::NotExistedTaskCompleted) do |event|
  Logger.new(STDOUT).warn event.inspect
end

event_store.evolve(task_stream, Producers::CreateTask.new(project),      id: 1, title: 'Create producer for creating tasks')
event_store.evolve(task_stream, Producers::CompleteTask.new(project),    id: 1)
event_store.evolve(task_stream, Producers::CreateTask.new(project),      id: 2, title: 'Create producer for updating task title')
event_store.evolve(task_stream, Producers::CreateTask.new(project),      id: 3, title: 'Allow to work with different tasks in same time')
event_store.evolve(task_stream, Producers::UpdateTaskTitle.new(project), id: 2, title: 'Update "Create producer for updating task title"')
event_store.evolve(task_stream, Producers::CompleteTask.new(project),    id: 2)
event_store.evolve(task_stream, Producers::CompleteTask.new(project),    id: 3)

events = event_store.get_stream(task_stream)

tasks_status = project.call(Projections::TotalAndCompletedTasks.new, {}, events)
all_tasks = project.call(Projections::AllTask.new, {}, events)

system("clear")

puts "Events for tasks:"
events.each { |e| puts "\t#{e.inspect}" }

puts "\nTasks state:"
puts "\t#{tasks_status}"

puts "\nTasks:"
(all_tasks[:tasks] || []).each { |task| puts "\t#{task}" }
