module k_multiple_free(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [3:0] n, // number of elements (1-16)
  input [15:0] k, // multiplier value
  input [9:0] elements [0:15], // input array (16 elements)
  output reg [4:0] result, // subset size (0-16)
  output reg done // high when computation complete
);

  // FSM states
  localparam IDLE = 0;
  localparam SORT = 1;
  localparam CHECK = 2;
  localparam DONE = 3;

  // State variables
  reg [1:0] state;
  reg [3:0] pass_count;   // 0-15 (16 passes)
  reg [3:0] i;            // for inner index in sort (0-14, then reset)
  reg [3:0] j;            // for second stage: current element index
  reg [9:0] elements_mem [0:15]; // memory for sorting
  reg [9:0] subset_mem [0:15];   // memory for subset
  reg [4:0] subset_count;        // count of selected elements
  reg [9:0] temp_swap;           // temporary for swapping in sort

  // Combinational logic for second stage: parallel comparators
  wire [25:0] prod = elements_mem[j] * k;
  wire [15:0] comp_outs;
  genvar m;
  generate
    for (m=0; m<16; m++) begin
      assign comp_outs[m] = (subset_count > m) && (prod == {16'b0, subset_mem[m]});
    end
  endgenerate
  wire skip = (comp_outs != 0);

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      pass_count <= 0;
      i <= 0;
      j <= 0;
      subset_count <= 0;
      temp_swap <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            // Load input array into memory, pad with zeros if needed
            for (int idx=0; idx<16; idx++) begin
              if (idx < n) 
                elements_mem[idx] <= elements[idx];
              else
                elements_mem[idx] <= 0;
            end
            pass_count <= 0;
            i <= 0;
            j <= 0;
            subset_count <= 0;
            state <= SORT;
          end
        end

        SORT: begin
          if (i < 15) begin
            // Compare and swap adjacent elements if out of order (for descending order)
            if (elements_mem[i] < elements_mem[i+1]) begin
              temp_swap <= elements_mem[i];
              elements_mem[i] <= elements_mem[i+1];
              elements_mem[i+1] <= temp_swap;
            end
            i <= i + 1;
          end
          else begin
            // End of pass
            i <= 0;
            pass_count <= pass_count + 1;
            if (pass_count == 15) begin // 16 passes done
              j <= 0;
              subset_count <= 0;
              state <= CHECK;
            end
          end
        end

        CHECK: begin
          if (j < n) begin
            if (skip) begin
              // Skip current element
              j <= j + 1;
            end
            else begin
              // Add current element to subset
              subset_mem[subset_count] <= elements_mem[j];
              subset_count <= subset_count + 1;
              j <= j + 1;
            end
          end
          else begin
            state <= DONE;
            result <= subset_count;
            done <= 1;
          end
        end

        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule