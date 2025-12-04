module potato_store_optimizer (
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [1:0] L,
  input [3:0][7:0] a,
  input [3:0][19:0] c,
  output reg [31:0] min_product,
  output reg done
);

  // State machine states
  localparam IDLE = 4'b0000;
  localparam INIT0 = 4'b0001;
  localparam INIT1 = 4'b0010;
  localparam RUN_S0 = 4'b0011;
  localparam RUN_S1 = 4'b0100;
  localparam RUN_S2 = 4'b0101;
  localparam RUN_S3 = 4'b0110;
  localparam RUN_S4 = 4'b0111;
  localparam RUN_S5 = 4'b1000;
  localparam DONE = 4'b1001;

  // State register
  reg [3:0] state;
  
  // Initialization registers
  reg [7:0] init_i;
  reg [19:0] total_potatoes;
  reg [19:0] total_price;
  
  // Assignment processing registers
  reg [3:0] assignment_counter;
  reg [3:0] current_mask;
  reg [2:0] K;
  reg valid_assignment;
  reg first_valid_assignment;
  
  // Temporary registers for current assignment
  reg [19:0] total_potatoes1;
  reg [19:0] total_price1;
  reg [19:0] total_potatoes2;
  reg [19:0] total_price2;
  
  // Division lookup table
  reg [31:0] div_table [16383:0];
  
  // Product calculation
  reg [31:0] P1;
  reg [31:0] P2;
  reg [31:0] product;
  
  // Generate the division lookup table
  genvar i, j;
  for (i = 0; i <= 512; i = i + 1) begin
    for (j = 1; j <= 32; j = j + 1) begin
      assign div_table[i * 32 + (j - 1)] = (i * 65536) / j;
    end
  end
  
  // State machine
  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      min_product <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT0;
            done <= 0;
          end
        end
        
        INIT0: begin
          total_potatoes <= 0;
          total_price <= 0;
          init_i <= 0;
          state <= INIT1;
        end
        
        INIT1: begin
          if (init_i < N) begin
            total_potatoes <= total_potatoes + a[init_i];
            total_price <= total_price + c[init_i];
            init_i <= init_i + 1;
          end else begin
            assignment_counter <= 0;
            first_valid_assignment <= 1;
            state <= RUN_S0;
          end
        end
        
        RUN_S0: begin
          current_mask <= assignment_counter[2:0]; // Use only N bits
          K <= $countones(current_mask[0 +: N]);
          valid_assignment <= ((K >= L) || (K <= (N - L))) && (K > 0) && (K < N);
          state <= RUN_S1;
        end
        
        RUN_S1: begin
          if (valid_assignment) begin
            if (0 < N) begin
              if (current_mask[0] == 1) begin
                total_potatoes1 <= a[0];
                total_price1 <= c[0];
              end else begin
                total_potatoes1 <= 0;
                total_price1 <= 0;
              end
            end else begin
              total_potatoes1 <= 0;
              total_price1 <= 0;
            end
          end
          state <= RUN_S2;
        end
        
        RUN_S2: begin
          if (valid_assignment) begin
            if (1 < N) begin
              if (current_mask[1] == 1) begin
                total_potatoes1 <= total_potatoes1 + a[1];
                total_price1 <= total_price1 + c[1];
              end
            end
          end
          state <= RUN_S3;
        end
        
        RUN_S3: begin
          if (valid_assignment) begin
            if (2 < N) begin
              if (current_mask[2] == 1) begin
                total_potatoes1 <= total_potatoes1 + a[2];
                total_price1 <= total_price1 + c[2];
              end
            end
          end
          state <= RUN_S4;
        end
        
        RUN_S4: begin
          if (valid_assignment) begin
            if (3 < N) begin
              if (current_mask[3] == 1) begin
                total_potatoes1 <= total_potatoes1 + a[3];
                total_price1 <= total_price1 + c[3];
              end
            end
          end
          state <= RUN_S5;
        end
        
        RUN_S5: begin
          if (valid_assignment) begin
            total_potatoes2 <= total_potatoes - total_potatoes1;
            total_price2 <= total_price - total_price1;
            
            // Calculate P1 and P2 using lookup table
            if (total_potatoes1 > 0) begin
              P1 <= div_table[total_price1 * 32 + (total_potatoes1 - 1)];
            end else begin
              P1 <= 0;
            end
            
            if (total_potatoes2 > 0) begin
              P2 <= div_table[total_price2 * 32 + (total_potatoes2 - 1)];
            end else begin
              P2 <= 0;
            end
            
            // Calculate product
            product <= (P1 * P2) >> 16;
            
            if (first_valid_assignment) begin
              min_product <= product;
              first_valid_assignment <= 0;
            end else if (product < min_product) begin
              min_product <= product;
            end
          end
          
          // Check if done
          if (assignment_counter == (1 << N) - 1) begin
            state <= DONE;
          end else begin
            assignment_counter <= assignment_counter + 1;
            state <= RUN_S0;
          end
        end
        
        DONE: begin
          state <= IDLE;
          done <= 1;
        end
        
        default: state <= IDLE;
      endcase
    end
  end
endmodule