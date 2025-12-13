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

  // Internal memory for up to 8 special item positions
  reg [7:0] p_mem [0:7];
  reg [3:0] load_count;     // counts loaded items (0..8)

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_LOAD   = 3'd1,
    S_INIT   = 3'd2,
    S_PAGE   = 3'd3,
    S_SHIFT  = 3'd4,
    S_DONE_W = 3'd5
  } state_t;

  state_t state, next_state;

  // Computation registers
  reg [7:0] shift;
  reg [3:0] op_count;
  reg [3:0] current_index; // index into p_mem (0..7)
  reg [2:0] done_cnt;      // to create 3-cycle latency

  // Temporary registers for page computation
  reg [7:0] base_val;
  reg [7:0] first_page;
  reg [7:0] page_end;
  reg [3:0] num_discarded;

  // Control signals
  reg compute_req;      // triggered by start
  reg compute_active;   // indicates computation in progress

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= S_IDLE;
      load_count     <= 4'd0;
      shift          <= 8'd0;
      op_count       <= 4'd0;
      current_index  <= 4'd0;
      out_op         <= 4'd0;
      done           <= 1'b0;
      done_cnt       <= 3'd0;
      compute_req    <= 1'b0;
      compute_active <= 1'b0;
      base_val       <= 8'd0;
      first_page     <= 8'd0;
      page_end       <= 8'd0;
      num_discarded  <= 4'd0;
    end else begin
      state <= next_state;

      // Capture special item positions while in LOAD state
      if (state == S_LOAD && p_valid && load_count < 4'd8) begin
        p_mem[load_count] <= p_data;
        load_count        <= load_count + 4'd1;
      end

      // Latch start as compute request (edge-level behavior)
      if (start && !compute_active) begin
        compute_req <= 1'b1;
      end else if (state == S_INIT) begin
        compute_req <= 1'b0;
      end

      // FSM actions
      case (state)
        S_IDLE: begin
          done           <= 1'b0;
          done_cnt       <= 3'd0;
          compute_active <= 1'b0;
          op_count       <= 4'd0;
          out_op         <= 4'd0;
          shift          <= 8'd0;
          current_index  <= 4'd0;
          if (p_valid) begin
            load_count <= 4'd0;
          end
        end

        S_LOAD: begin
          done     <= 1'b0;
          done_cnt <= 3'd0;
        end

        S_INIT: begin
          // Initialize computation
          compute_active <= 1'b1;
          done           <= 1'b0;
          done_cnt       <= 3'd0;
          op_count       <= 4'd0;
          shift          <= 8'd0;
          current_index  <= 4'd0;
        end

        S_PAGE: begin
          // Compute page for current batch
          if (current_index < m) begin
            base_val   <= p_mem[current_index] - shift - 8'd1;
            first_page <= (p_mem[current_index] - shift - 8'd1) / k;
            page_end   <= (((p_mem[current_index] - shift - 8'd1) / k) + 8'd1) * k;
            // Count how many items fit into this shifted page
            num_discarded <= 4'd0;
            if (current_index < m && (p_mem[current_index] - shift) <= page_end)
              num_discarded <= num_discarded + 4'd1;
            if ((current_index + 4'd1) < m && (p_mem[current_index + 4'd1] - shift) <= page_end)
              num_discarded <= num_discarded + 4'd1;
            if ((current_index + 4'd2) < m && (p_mem[current_index + 4'd2] - shift) <= page_end)
              num_discarded <= num_discarded + 4'd1;
            if ((current_index + 4'd3) < m && (p_mem[current_index + 4'd3] - shift) <= page_end)
              num_discarded <= num_discarded + 4'd1;
            if ((current_index + 4'd4) < m && (p_mem[current_index + 4'd4] - shift) <= page_end)
              num_discarded <= num_discarded + 4'd1;
            if ((current_index + 4'd5) < m && (p_mem[current_index + 4'd5] - shift) <= page_end)
              num_discarded <= num_discarded + 4'd1;
            if ((current_index + 4'd6) < m && (p_mem[current_index + 4'd6] - shift) <= page_end)
              num_discarded <= num_discarded + 4'd1;
            if ((current_index + 4'd7) < m && (p_mem[current_index + 4'd7] - shift) <= page_end)
              num_discarded <= num_discarded + 4'd1;
          end
        end

        S_SHIFT: begin
          // Apply shift and update counters for this operation
          if (num_discarded != 4'd0) begin
            shift         <= shift + num_discarded;
            current_index <= current_index + num_discarded;
            op_count      <= op_count + 4'd1;
          end
        end

        S_DONE_W: begin
          // 3-cycle latency after operations complete
          if (done_cnt < 3'd3) begin
            done_cnt <= done_cnt + 3'd1;
            if (done_cnt == 3'd2) begin
              out_op <= op_count;
              done   <= 1'b1;
            end
          end
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
      S_IDLE: begin
        if (p_valid)
          next_state = S_LOAD;
        else if (start)
          next_state = S_INIT;
      end

      S_LOAD: begin
        if (compute_req || start)
          next_state = S_INIT;
      end

      S_INIT: begin
        if (m == 8'd0)
          next_state = S_DONE_W;
        else
          next_state = S_PAGE;
      end

      S_PAGE: begin
        if (current_index >= m)
          next_state = S_DONE_W;
        else
          next_state = S_SHIFT;
      end

      S_SHIFT: begin
        if (current_index >= m)
          next_state = S_DONE_W;
        else
          next_state = S_PAGE;
      end

      S_DONE_W: begin
        if (done_cnt >= 3'd3)
          next_state = S_IDLE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule