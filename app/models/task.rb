class Task < ApplicationRecord
  belongs_to :user
  
  enum status: { pending: 0, in_progress: 1, completed: 2, failed: 3 }
  enum task_type: { appointment_scheduling: 0, email_response: 1, contact_creation: 2, general: 3 }
  
  validates :title, presence: true
  validates :status, presence: true
  validates :task_type, presence: true
  
  def update_progress(progress_data)
    update(
      progress: progress_data,
      updated_at: Time.current
    )
  end
  
  def add_step(step_description)
    current_steps = steps || []
    current_steps << {
      timestamp: Time.current.iso8601,
      description: step_description
    }
    update(steps: current_steps)
  end
  
  def mark_completed(result = nil)
    update(
      status: :completed,
      result: result,
      completed_at: Time.current
    )
  end
  
  def mark_failed(error_message = nil)
    update(
      status: :failed,
      error_message: error_message,
      failed_at: Time.current
    )
  end
end 