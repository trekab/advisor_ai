class InstructionsController < ApplicationController
  before_action :require_login
  before_action :set_instruction, only: [:edit, :update, :destroy]

  def index
    @instructions = current_user.instructions.order(created_at: :desc)
  end

  def edit
  end

  def update
    if @instruction.update(instruction_params)
      redirect_to instructions_path, notice: 'Instruction updated.'
    else
      render :edit
    end
  end

  def destroy
    @instruction.destroy
    redirect_to instructions_path, notice: 'Instruction deleted.'
  end

  private

  def set_instruction
    @instruction = current_user.instructions.find(params[:id])
  end

  def instruction_params
    params.require(:instruction).permit(:content)
  end
end
