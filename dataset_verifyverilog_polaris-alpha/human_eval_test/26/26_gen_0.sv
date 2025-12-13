module remove_duplicates(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [3:0]  data_in [7:0],
  output logic [3:0]  data_out [7:0],
  output logic [7:0]  valid_mask,
  output logic        done
);

  typedef enum logic [1:0] {
    S_IDLE  = 2'b00,
    S_WAIT  = 2'b01,
    S_DONE  = 2'b10
  } state_t;

  state_t      state, next_state;
  logic [3:0]  latched_data [7:0];
  logic [7:0]  unique_mask;
  logic [2:0]  latched_idx [7:0];
  logic [2:0]  out_count;
  logic [2:0]  cycle_cnt;

  // Latch input data and initialize on start
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      cycle_cnt   <= 3'd0;
      out_count   <= 3'd0;
      done        <= 1'b0;
      valid_mask  <= 8'b0;
      unique_mask <= 8'b0;
      data_out[0] <= 4'd0;
      data_out[1] <= 4'd0;
      data_out[2] <= 4'd0;
      data_out[3] <= 4'd0;
      data_out[4] <= 4'd0;
      data_out[5] <= 4'd0;
      data_out[6] <= 4'd0;
      data_out[7] <= 4'd0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch input data
            latched_data[0] <= data_in[0];
            latched_data[1] <= data_in[1];
            latched_data[2] <= data_in[2];
            latched_data[3] <= data_in[3];
            latched_data[4] <= data_in[4];
            latched_data[5] <= data_in[5];
            latched_data[6] <= data_in[6];
            latched_data[7] <= data_in[7];

            // Precompute unique_mask combinationally in next block; no change here
            cycle_cnt  <= 3'd0;
            out_count  <= 3'd0;
            valid_mask <= 8'b0;
            data_out[0] <= 4'd0;
            data_out[1] <= 4'd0;
            data_out[2] <= 4'd0;
            data_out[3] <= 4'd0;
            data_out[4] <= 4'd0;
            data_out[5] <= 4'd0;
            data_out[6] <= 4'd0;
            data_out[7] <= 4'd0;
          end
        end

        S_WAIT: begin
          // 8-cycle latency counter
          if (cycle_cnt < 3'd7)
            cycle_cnt <= cycle_cnt + 3'd1;

          // On the 7th->8th cycle (cycle_cnt==7 before increment), populate outputs
          if (cycle_cnt == 3'd7) begin
            integer i;
            out_count  <= 3'd0;
            valid_mask <= 8'b0;
            data_out[0] <= 4'd0;
            data_out[1] <= 4'd0;
            data_out[2] <= 4'd0;
            data_out[3] <= 4'd0;
            data_out[4] <= 4'd0;
            data_out[5] <= 4'd0;
            data_out[6] <= 4'd0;
            data_out[7] <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
              if (unique_mask[i]) begin
                data_out[out_count] <= latched_data[i];
                valid_mask[out_count] <= 1'b1;
                out_count <= out_count + 3'd1;
              end
            end
          end
        end

        S_DONE: begin
          done <= 1'b1;
          // Hold outputs stable until next start or reset
        end

        default: begin
          // Should not occur
        end
      endcase
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_WAIT;
      end
      S_WAIT: begin
        if (cycle_cnt == 3'd7)
          next_state = S_DONE;
      end
      S_DONE: begin
        if (start)
          next_state = S_WAIT;
        else if (!start)
          next_state = S_DONE;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Compute unique_mask combinationally from latched_data
  always_comb begin
    integer i, j;
    for (i = 0; i < 8; i = i + 1) begin
      int count;
      count = 0;
      for (j = 0; j < 8; j = j + 1) begin
        if (latched_data[i] == latched_data[j])
          count = count + 1;
      end
      unique_mask[i] = (count == 1);
    end
  end

endmodule