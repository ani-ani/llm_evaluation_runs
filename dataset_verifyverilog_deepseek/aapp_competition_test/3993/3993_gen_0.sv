module page_operations_counter(
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  input [7:0] m,
  input [7:0] k,
  input [7:0] p_data,
  input p_valid,
  output reg [3:0] out_op,
  output reg done
);

  reg [7:0] p_mem [0:7];
  reg [3:0] p_count;
  
  typedef enum logic [1:0] {IDLE, START_ST, COMPUTE, DONE_WAIT} state_t;
  state_t state, next_state;

  reg [7:0] shift_reg;
  reg [3:0] op_count_reg;
  reg [3:0] current_idx_reg;
  reg [1:0] done_counter;
  reg [7:0] m_reg, k_reg;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      p_count <= 4'b0;
    end else if (state == IDLE && p_valid && (p_count < m_reg)) begin
      automatic logic [3:0] ins_pos = p_count;
      for (int i=0; i<p_count; i++) begin
        if (p_data < p_mem[i]) begin
          ins_pos = i;
          break;
        end
      end
      for (int j=p_count; j>ins_pos; j--) begin
        p_mem[j] <= p_mem[j-1];
      end
      p_mem[ins_pos] <= p_data;
      p_count <= p_count + 1;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      shift_reg <= 8'b0;
      op_count_reg <= 4'b0;
      current_idx_reg <= 4'b0;
      done <= 1'b0;
      done_counter <= 2'b0;
      m_reg <= 8'b0;
      k_reg <= 8'b0;
      out_op <= 4'b0;
    end else begin
      state <= next_state;
      done <= 1'b0;

      case (state)
        IDLE: begin
          if (start) begin
            m_reg <= m;
            k_reg <= k;
          end
        end
        START_ST: begin
          shift_reg <= 8'b0;
          op_count_reg <= 4'b0;
          current_idx_reg <= 4'b0;
        end
        COMPUTE: begin
          if (current_idx_reg < m_reg) begin
            automatic logic [7:0] a = p_mem[current_idx_reg] - shift_reg - 1;
            automatic logic [7:0] first_page = (k_reg != 0) ? a / k_reg : 0;
            automatic logic [7:0] next_end = (first_page + 1) * k_reg;
            automatic logic [3:0] cnt = 0;
            
            for (int i= current_idx_reg; i < m_reg; i++) begin
              if ((p_mem[i] - shift_reg) <= next_end) begin
                cnt++;
              end else break;
            end
            
            op_count_reg <= op_count_reg + 1;
            shift_reg <= shift_reg + cnt;
            current_idx_reg <= current_idx_reg + cnt;
          end
        end
        DONE_WAIT: begin
          if (done_counter == 0) begin
            out_op <= op_count_reg;
            done <= 1'b1;
          end else begin
            done_counter <= done_counter - 1;
          end
        end
      endcase
    end
  end

  always_comb begin
    next_state = state;
    
    case (state)
      IDLE: next_state = (start) ? START_ST : IDLE;
      START_ST: next_state = COMPUTE;
      COMPUTE: next_state = (current_idx_reg >= m_reg) ? DONE_WAIT : COMPUTE;
      DONE_WAIT: next_state = (done_counter == 0) ? IDLE : DONE_WAIT;
      default: next_state = IDLE;
    endcase
  end
endmodule