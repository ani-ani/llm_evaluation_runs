module sort_dict_by_val(
  input clk,
  input rst_n,
  input start,
  input [3:0] size,
  input [3:0] keys_in [0:3],
  input [15:0] vals_in [0:3],
  output reg [3:0] sorted_keys [0:3],
  output reg [15:0] sorted_vals [0:3],
  output reg done
);  
  
  typedef enum {IDLE, SORTING, DONE} state_t;
  reg [1:0] i, j;
  reg [3:0] key_reg[0:3];
  reg [15:0] val_reg[0:3];
  state_t state;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      sorted_keys <= '{0,0,0,0};
      sorted_vals <= '{0,0,0,0};
      state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            // Load inputs & clear unused entries
            for (int idx=0; idx<4; idx++) begin
              key_reg[idx] <= (idx < size) ? keys_in[idx] : 4'b0;
              val_reg[idx] <= (idx < size) ? vals_in[idx] : 16'b0;
            end
            i <= 0;
            j <= 0;
            state <= SORTING;
          end
        end
        
        SORTING: begin
          if (j < 3 - i) begin
            // Compare adjacent elements
            if (val_reg[j] < val_reg[j+1]) begin
              // Swap values
              val_reg[j]   <= val_reg[j+1];
              val_reg[j+1] <= val_reg[j];
              // Swap keys
              key_reg[j]   <= key_reg[j+1];
              key_reg[j+1] <= key_reg[j];
            end
            j <= j + 1;
          end else begin
            // End of current pass
            j <= 0;
            if (i == (size > 1 ? size-2 : 0)) begin
              state <= DONE;
            end else begin
              i <= i + 1;
            end
          end
        end
        
        DONE: begin
          sorted_keys <= key_reg;
          sorted_vals <= val_reg;
          done <= 1;
          if (!start) state <= IDLE; // Wait for start deassertion
        end
      endcase
    end
  end
endmodule