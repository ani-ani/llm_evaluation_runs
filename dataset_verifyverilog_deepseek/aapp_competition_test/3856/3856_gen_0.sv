module min_photo_area(
  input clk,
  input rst_n,
  input start,
  input [1:0] n,
  input [3:0] w0, w1, w2, w3,
  input [3:0] h0, h1, h2, h3,
  output reg [15:0] min_area,
  output reg done
);

// State encoding
typedef enum logic [2:0] {
  IDLE=0, INIT=1, LOOP_H=2, CHECK_MANDATORY=3, 
  CALC_OPTIONAL=4, SUM_WIDTH=5, UPDATE_MIN=6, DONE=7} state_t;

state_t state_reg, state_next;

// Internal registers
reg [3:0] max_height_reg;
reg [1:0] n_reg;
reg [3:0] w_reg [0:3];
reg [3:0] h_reg [0:3];
reg [3:0] mandatory;
reg [3:0] flippable;
reg [3:0] selected_optional;
reg [3:0] friend_index;
reg [1:0] mandatory_count;
reg [1:0] remaining_flips;
reg reject_flag;
reg [6:0] total_width;
wire [1:0] floor_n_div2 = n_reg >> 1;

// Combinational outputs
wire [10:0] product = total_width * max_height_reg;

// Registered outputs
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    min_area <= '1;
    done <= 0;
    state_reg <= IDLE;
  end else begin
    state_reg <= state_next;
    
    case (state_reg)
      INIT: begin
        n_reg <= n;
        w_reg[0] <= w0; w_reg[1] <= w1;
        w_reg[2] <= w2; w_reg[3] <= w3;
        h_reg[0] <= h0; h_reg[1] <= h1;
        h_reg[2] <= h2; h_reg[3] <= h3;
        min_area <= '1;
        done <= 0;
        max_height_reg <= 1;
      end
      
      LOOP_H: if (state_next != LOOP_H) begin
        if (max_height_reg < 15) max_height_reg <= max_height_reg + 1;
      end
      
      UPDATE_MIN: if (product < min_area) min_area <= {5'b0, product};
      
      DONE: done <= 1;
    endcase
  end
end

// Combinational state + control logic
always_comb begin
  // Defaults
  state_next = state_reg;
  mandatory = 0;
  flippable = 0;
  selected_optional = 0;
  mandatory_count = 0;
  reject_flag = 0;
  total_width = 0;

  case (state_reg)
    IDLE: if (start) state_next = INIT;
    
    INIT: state_next = LOOP_H;
    
    LOOP_H: begin
      if (max_height_reg > 15) state_next = DONE;
      else state_next = CHECK_MANDATORY;
    end
    
    CHECK_MANDATORY: begin
      // Evaluate mandatory flips
      for (int i=0; i<4; i++) begin
        if (i < n_reg) begin
          if (h_reg[i] > max_height_reg) begin
            mandatory[i] = 1;
            mandatory_count++;
            if (w_reg[i] > max_height_reg) reject_flag = 1;
          end
        end
      end
      
      if (reject_flag || (mandatory_count > floor_n_div2)) begin
        if (max_height_reg < 15) state_next = LOOP_H;
        else state_next = DONE;
      end else begin
        remaining_flips = floor_n_div2 - mandatory_count;
        state_next = CALC_OPTIONAL;
      end
    end
    
    CALC_OPTIONAL: begin
      // Tag flippable friends
      for (int i=0; i<4; i++) begin
        if (i < n_reg && !mandatory[i] && (h_reg[i] <= max_height_reg) && (w_reg[i] > h_reg[i]))
          flippable[i] = 1;
      end
      
      // Select optional flips logic
      if (remaining_flips > 0) begin
        // Diff values for flippable friends
        logic [3:0] diff[4];
        for (int i=0; i<4; i++) diff[i] = flippable[i] ? (w_reg[i] - h_reg[i]) : 4'b0;
        
        // Find first max
        logic [1:0] max_idx1 = 0;
        for (int i=1; i<4; i++) begin
          if (diff[i] > diff[max_idx1]) max_idx1 = i;
        end
        
        if (diff[max_idx1] > 0 && flippable[max_idx1]) begin
          selected_optional[max_idx1] = 1;
          remaining_flips--;
        end
        
        // Find second max (if needed)
        if (remaining_flips > 0) begin
          logic [1:0] max_idx2;
          logic first = 1;
          
          for (int i=0; i<4; i++) begin
            if (i != max_idx1 && flippable[i]) begin
              if (first) begin
                max_idx2 = i;
                first = 0;
              end else if (diff[i] > diff[max_idx2]) begin
                max_idx2 = i;
              end
            end
          end
          
          if (!first && diff[max_idx2] > 0 && flippable[max_idx2]) begin
            selected_optional[max_idx2] = 1;
          end
        end
      end
      
      state_next = SUM_WIDTH;
    end
    
    SUM_WIDTH: begin
      for (int i=0; i<4; i++) begin
        if (i < n_reg) begin
          if (mandatory[i] || selected_optional[i])
            total_width += h_reg[i];
          else
            total_width += w_reg[i];
        end
      end
      state_next = UPDATE_MIN;
    end
    
    UPDATE_MIN: state_next = LOOP_H;
    
    DONE: if (start) state_next = INIT;
    
    default: state_next = IDLE;
  endcase
end

endmodule