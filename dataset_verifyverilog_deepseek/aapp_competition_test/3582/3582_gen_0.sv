module mentor_assign (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] current_mentors [0:7],
  output reg [2:0] new_mentors [0:7],
  output reg done
);

  typedef enum logic [2:0] {IDLE, STAGE1, STAGE2, STAGE3, DONE_ST} state_t;
  state_t current_state, next_state;

  logic valid_cycle;
  logic [7:0] visited;
  logic [2:0] current_g;
  logic [2:0] step_count;
  logic [7:0] mentored_by;
  logic [2:0] temp_mentors [0:7];
  logic [2:0] g;

  function automatic logic is_single_cycle(input [2:0] num_g, input [2:0] mentors [0:7]);
    logic [7:0] visited = 0;
    logic [2:0] current = 0;
    logic [2:0] count = 0;
    if (num_g == 0) return 0;
    
    while (!visited[current] && count < num_g) begin
      visited[current] = 1;
      current = mentors[current];
      count++;
      if (current >= num_g) return 0;
    end
    
    return (current == 0) && (count == num_g) && (&visited[num_g-1:0] | (num_g == 1));
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      foreach (new_mentors[i]) new_mentors[i] <= 3'b0;
    end else begin
      current_state <= next_state;
      case (current_state)
        IDLE: begin
          done <= 0;
          if (start) next_state <= STAGE1;
        end
        
        STAGE1: begin
          foreach (new_mentors[i]) new_mentors[i] <= (i < n) ? current_mentors[i] : 3'b0;
          next_state <= STAGE2;
        end
        
        STAGE2: begin
          valid_cycle <= is_single_cycle(n, new_mentors);
          if (valid_cycle) next_state <= DONE_ST;
          else next_state <= STAGE3;
        end
        
        STAGE3: begin
          mentored_by <= '0;
          foreach (temp_mentors[i]) begin
            if (i < n) begin
              automatic logic [2:0] orig_ment = current_mentors[i];
              if ((orig_ment < n) && !mentored_by[orig_ment] && orig_ment != i) begin
                temp_mentors[i] <= orig_ment;
                mentored_by[orig_ment] <= 1'b1;
              end else begin
                for (int j=0; j<8; j++) begin
                  if ((j < n) && !mentored_by[j] && j != i) begin
                    temp_mentors[i] <= j;
                    mentored_by[j] <= 1'b1;
                    break;
                  end
                end
              end
            end else begin
              temp_mentors[i] <= 3'b0;
            end
          end
          next_state <= DONE_ST;
        end
        
        DONE_ST: begin
          if (!valid_cycle) new_mentors <= temp_mentors;
          done <= 1'b1;
          next_state <= IDLE;
        end
      endcase
    end
  end

  always_comb begin
    case (current_state)
      IDLE: next_state = start ? STAGE1 : IDLE;
      STAGE1: next_state = STAGE2;
      STAGE2: next_state = valid_cycle ? DONE_ST : STAGE3;
      STAGE3: next_state = DONE_ST;
      DONE_ST: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end
endmodule