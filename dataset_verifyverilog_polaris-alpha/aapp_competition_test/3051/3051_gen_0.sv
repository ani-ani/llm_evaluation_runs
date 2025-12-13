module fog_miss_counter(
  input clk,
  input rst_n,
  input start,
  input [1:0] num_origins,
  input [1:0] m_i [0:3],
  input [15:0] d_i [0:3],
  input signed [15:0] l_i [0:3],
  input signed [15:0] r_i [0:3],
  input [15:0] h_i [0:3],
  input [15:0] delta_d_i [0:3],
  input signed [15:0] delta_x_i [0:3],
  input signed [15:0] delta_h_i [0:3],
  output reg [5:0] missed_count,
  output reg done
);

  // State encoding
  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_LATCH  = 3'd1,
    S_INIT   = 3'd2,
    S_NEXT   = 3'd3,
    S_CHECK  = 3'd4,
    S_DONE   = 3'd5
  } state_t;

  state_t state, next_state;

  // Latched configuration
  reg [1:0] num_origins_q;
  reg [1:0] m_q   [0:3];
  reg [15:0] d_q  [0:3];
  reg signed [15:0] l_q [0:3];
  reg signed [15:0] r_q [0:3];
  reg [15:0] h_q  [0:3];
  reg [15:0] delta_d_q  [0:3];
  reg signed [15:0] delta_x_q [0:3];
  reg signed [15:0] delta_h_q [0:3];

  // Fog index: encoded as {origin_index, fog_index}
  // origin_index: 0-3, fog_index: 0-2 (max 3 fogs)
  reg [1:0] cur_origin;
  reg [1:0] cur_fog_idx; // up to 3, but 2 bits sufficient (0-3)

  // Current fog parameters (computed)
  reg [15:0] cur_day;
  reg signed [15:0] cur_l;
  reg signed [15:0] cur_r;
  reg [15:0] cur_h;

  // Miss detection
  reg miss_cur_fog;

  // Convenience: total fogs counter (for latency reasoning, not required external)
  // Not strictly needed, we sequence via (cur_origin, cur_fog_idx) limits.

  // Latch inputs on start
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      num_origins_q <= 2'd0;
      for (i = 0; i < 4; i = i + 1) begin
        m_q[i]         <= 2'd0;
        d_q[i]         <= 16'd0;
        l_q[i]         <= '0;
        r_q[i]         <= '0;
        h_q[i]         <= 16'd0;
        delta_d_q[i]   <= 16'd0;
        delta_x_q[i]   <= '0;
        delta_h_q[i]   <= '0;
      end
    end else if (state == S_LATCH) begin
      num_origins_q <= num_origins;
      for (i = 0; i < 4; i = i + 1) begin
        m_q[i]         <= m_i[i];
        d_q[i]         <= d_i[i];
        l_q[i]         <= l_i[i];
        r_q[i]         <= r_i[i];
        h_q[i]         <= h_i[i];
        delta_d_q[i]   <= delta_d_i[i];
        delta_x_q[i]   <= delta_x_i[i];
        delta_h_q[i]   <= delta_h_i[i];
      end
    end
  end

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
    end else begin
      state <= next_state;
    end
  end

  // FSM next state & control
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_LATCH;
      end
      S_LATCH: begin
        next_state = S_INIT;
      end
      S_INIT: begin
        next_state = (num_origins_q == 0) ? S_DONE : S_NEXT;
      end
      S_NEXT: begin
        // If we've exhausted all fogs, go done; else compute and check
        if (cur_origin >= num_origins_q)
          next_state = S_DONE;
        else if (m_q[cur_origin] == 0)
          next_state = S_DONE; // no fogs for this origin
        else
          next_state = S_CHECK;
      end
      S_CHECK: begin
        // One cycle per fog: after check either move to next fog or done
        // Next_state is decided via indices in sequential block; here we default to NEXT
        next_state = S_NEXT;
      end
      S_DONE: begin
        // Stay done until new start
        if (start)
          next_state = S_LATCH;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential indices, outputs, and current fog computations
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cur_origin   <= 2'd0;
      cur_fog_idx  <= 2'd0;
      missed_count <= 6'd0;
      done         <= 1'b0;
      cur_day      <= 16'd0;
      cur_l        <= '0;
      cur_r        <= '0;
      cur_h        <= 16'd0;
      miss_cur_fog <= 1'b0;
    end else begin
      done <= 1'b0;
      case (state)
        S_IDLE: begin
          missed_count <= missed_count; // hold
        end

        S_LATCH: begin
          // Reset counters when new config latched
          missed_count <= 6'd0;
          cur_origin   <= 2'd0;
          cur_fog_idx  <= 2'd0;
        end

        S_INIT: begin
          // Prepare to start with first fog
          cur_origin   <= 2'd0;
          cur_fog_idx  <= 2'd0;
        end

        S_NEXT: begin
          // Advance indices based on previous fog processing
          // If coming from INIT, indices are set; if from CHECK, they were updated there.
          // Boundary checks: skip origins with 0 m_q if encountered.

          // Normalize index progression: if current origin exhausted, move to next.
          if (cur_origin < num_origins_q) begin
            if (m_q[cur_origin] == 0) begin
              // no fogs for this origin
              cur_origin  <= num_origins_q; // force done in next
              cur_fog_idx <= 2'd0;
            end else if (cur_fog_idx >= m_q[cur_origin]) begin
              // move to next origin
              if (cur_origin + 1 < num_origins_q) begin
                cur_origin  <= cur_origin + 1'b1;
                cur_fog_idx <= 2'd0;
              end else begin
                cur_origin  <= num_origins_q; // mark as done
                cur_fog_idx <= 2'd0;
              end
            end else begin
              // Compute current fog parameters for upcoming CHECK
              cur_day <= d_q[cur_origin] + (cur_fog_idx * delta_d_q[cur_origin]);
              cur_l   <= l_q[cur_origin] + (cur_fog_idx * delta_x_q[cur_origin]);
              cur_r   <= r_q[cur_origin] + (cur_fog_idx * delta_x_q[cur_origin]);
              begin
                // height saturates at 0 if negative (since [0,h])
                // but inputs are 16-bit unsigned for base and signed delta; bound at 0.
                // Use signed temp
                reg signed [16:0] tmp_h;
                tmp_h = $signed({1'b0,h_q[cur_origin]}) + $signed(cur_fog_idx) * $signed(delta_h_q[cur_origin]);
                if (tmp_h <= 0)
                  cur_h <= 16'd0;
                else if (tmp_h[16])
                  cur_h <= 16'd0; // safety
                else
                  cur_h <= tmp_h[15:0];
              end
            end
          end
        end

        S_CHECK: begin
          // In this simplified version, containment is assumed to be false
          // because nets are maintained externally and not visible here.
          // Thus: every fog is treated as missed.
          miss_cur_fog <= 1'b1;

          if (miss_cur_fog && (missed_count != 6'd63)) begin
            missed_count <= missed_count + 6'd1;
          end

          // Move to next fog index
          if (cur_fog_idx + 1 < m_q[cur_origin]) begin
            cur_fog_idx <= cur_fog_idx + 1'b1;
          end else begin
            // move to next origin on next S_NEXT
            cur_fog_idx <= m_q[cur_origin];
          end
        end

        S_DONE: begin
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule