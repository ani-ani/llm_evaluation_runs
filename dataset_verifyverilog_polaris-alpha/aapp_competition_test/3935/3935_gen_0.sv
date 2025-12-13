module bipartite_graph_eraser(
  input clk,
  input rst_n,
  input start,
  input [15:0] data_in,
  output reg [15:0] erased_element,
  output reg element_valid,
  output reg [3:0] erased_count,
  output reg done
);

  // State encoding
  localparam IDLE    = 3'd0;
  localparam LOAD    = 3'd1;
  localparam PROCESS = 3'd2;
  localparam OUTPUT  = 3'd3;
  localparam DONE_ST = 3'd4;

  reg [2:0] state, next_state;

  // Storage for 8 input elements
  reg [15:0] in_mem [0:7];
  reg [2:0]  load_idx;

  // Group counts by exponent (0..15)
  reg [3:0] group_count [0:15];

  // Exponent per element (0..15)
  reg [3:0] elem_exp [0:7];

  // Working signals
  reg [3:0] curr_exp;
  reg [2:0] proc_idx;
  reg [3:0] max_group_idx;
  reg [3:0] max_group_count;

  reg [2:0] out_idx;
  reg [3:0] total_erased;

  // Trailing zero count function (CTZ), treats zero as exponent 0
  function automatic [3:0] ctz16;
    input [15:0] v;
    begin
      if (v[0])       ctz16 = 4'd0;
      else if (v[1])  ctz16 = 4'd1;
      else if (v[2])  ctz16 = 4'd2;
      else if (v[3])  ctz16 = 4'd3;
      else if (v[4])  ctz16 = 4'd4;
      else if (v[5])  ctz16 = 4'd5;
      else if (v[6])  ctz16 = 4'd6;
      else if (v[7])  ctz16 = 4'd7;
      else if (v[8])  ctz16 = 4'd8;
      else if (v[9])  ctz16 = 4'd9;
      else if (v[10]) ctz16 = 4'd10;
      else if (v[11]) ctz16 = 4'd11;
      else if (v[12]) ctz16 = 4'd12;
      else if (v[13]) ctz16 = 4'd13;
      else if (v[14]) ctz16 = 4'd14;
      else if (v[15]) ctz16 = 4'd15;
      else            ctz16 = 4'd0; // for v == 0
    end
  endfunction

  // Sequential state and registers
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      load_idx <= 3'd0;
      proc_idx <= 3'd0;
      max_group_idx <= 4'd0;
      max_group_count <= 4'd0;
      out_idx <= 3'd0;
      total_erased <= 4'd0;
      erased_element <= 16'd0;
      element_valid <= 1'b0;
      erased_count <= 4'd0;
      done <= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        in_mem[i] <= 16'd0;
        elem_exp[i] <= 4'd0;
      end
      for (i = 0; i < 16; i = i + 1) begin
        group_count[i] <= 4'd0;
      end
    end else begin
      state <= next_state;

      // Default strobes
      element_valid <= 1'b0;
      done <= 1'b0;

      case (state)
        IDLE: begin
          // Wait for start; clear context when entering IDLE
          load_idx <= 3'd0;
          proc_idx <= 3'd0;
          max_group_idx <= 4'd0;
          max_group_count <= 4'd0;
          out_idx <= 3'd0;
          total_erased <= 4'd0;
          erased_element <= 16'd0;
          erased_count <= 4'd0;
          for (i = 0; i < 8; i = i + 1) begin
            elem_exp[i] <= 4'd0;
          end
          for (i = 0; i < 16; i = i + 1) begin
            group_count[i] <= 4'd0;
          end
          if (start) begin
            // Capture first element on transition to LOAD
            in_mem[0] <= data_in;
            elem_exp[0] <= ctz16(data_in);
            group_count[ctz16(data_in)] <= group_count[ctz16(data_in)] + 4'd1;
            load_idx <= 3'd1;
          end
        end

        LOAD: begin
          // Capture 8 input elements, one per cycle while start is high
          if (start && load_idx < 3'd8) begin
            in_mem[load_idx] <= data_in;
            curr_exp = ctz16(data_in);
            elem_exp[load_idx] <= curr_exp;
            group_count[curr_exp] <= group_count[curr_exp] + 4'd1;
            load_idx <= load_idx + 3'd1;
          end
        end

        PROCESS: begin
          // Single-cycle processing: find max group and total_erased
          max_group_idx <= 4'd0;
          max_group_count <= 4'd0;
          for (i = 0; i < 16; i = i + 1) begin
            if (group_count[i] > max_group_count) begin
              max_group_count <= group_count[i];
              max_group_idx <= i[3:0];
            end
          end
          // Compute total_erased = 8 - max_group_count
          total_erased <= 4'd8 - max_group_count;
          erased_count <= 4'd8 - max_group_count;
          out_idx <= 3'd0;
        end

        OUTPUT: begin
          // Output elements not in max group, one per cycle
          if (out_idx < 3'd8) begin
            if (elem_exp[out_idx] != max_group_idx) begin
              erased_element <= in_mem[out_idx];
              element_valid <= 1'b1;
            end else begin
              erased_element <= 16'd0;
              element_valid <= 1'b0;
            end
            out_idx <= out_idx + 3'd1;
          end
        end

        DONE_ST: begin
          done <= 1'b1;
          erased_element <= 16'd0;
          element_valid <= 1'b0;
        end

        default: begin
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = LOAD;
      end

      LOAD: begin
        if (load_idx == 3'd8)
          next_state = PROCESS;
        else
          next_state = LOAD;
      end

      PROCESS: begin
        // PROCESS is single cycle
        next_state = OUTPUT;
      end

      OUTPUT: begin
        if (out_idx == 3'd8)
          next_state = DONE_ST;
        else
          next_state = OUTPUT;
      end

      DONE_ST: begin
        // Wait until start deasserted, then go back to IDLE
        if (!start)
          next_state = IDLE;
        else
          next_state = DONE_ST;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule