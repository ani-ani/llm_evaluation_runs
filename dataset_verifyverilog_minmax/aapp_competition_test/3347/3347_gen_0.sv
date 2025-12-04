module gold_store_optimizer(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] t_i_0, input [15:0] h_i_0,
  input [15:0] t_i_1, input [15:0] h_i_1,
  input [15:0] t_i_2, input [15:0] h_i_2,
  input [15:0] t_i_3, input [15:0] h_i_3,
  input [15:0] t_i_4, input [15:0] h_i_4,
  input [15:0] t_i_5, input [15:0] h_i_5,
  input [15:0] t_i_6, input [15:0] h_i_6,
  input [15:0] t_i_7, input [15:0] h_i_7,
  output reg [3:0] max_count,
  output reg done
);

  localparam NUM_STORES = 8;
  localparam IDLE       = 2'b00;
  localparam SORT       = 2'b01;
  localparam ACCUMULATE = 2'b10;
  localparam DONE       = 2'b11;

  // Buffers for sorting
  reg [15:0] t [0:NUM_STORES-1];
  reg [15:0] h [0:NUM_STORES-1];
  reg [15:0] t_tmp [0:NUM_STORES-1];
  reg [15:0] h_tmp [0:NUM_STORES-1];

  // Sorting control
  reg [3:0] pass;
  reg [3:0] j;
  reg       swapped;
  reg       sort_done;

  // Accumulation control
  reg [15:0] total_time;
  reg [3:0]  i;
  reg [3:0]  acc_count;

  reg [1:0] state, next_state;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_count <= 4'b0;
      done      <= 1'b1; // idle done-high until start pulses
    end else begin
      max_count <= max_count;
      done      <= done;
    end
  end

  // Sorting buffers initialization on start
  always @(posedge clk) begin
    if (start) begin
      t[0] <= t_i_0; h[0] <= h_i_0;
      t[1] <= t_i_1; h[1] <= h_i_1;
      t[2] <= t_i_2; h[2] <= h_i_2;
      t[3] <= t_i_3; h[3] <= h_i_3;
      t[4] <= t_i_4; h[4] <= h_i_4;
      t[5] <= t_i_5; h[5] <= h_i_5;
      t[6] <= t_i_6; h[6] <= h_i_6;
      t[7] <= t_i_7; h[7] <= h_i_7;
    end else begin
      t[0] <= t[0]; h[0] <= h[0];
      t[1] <= t[1]; h[1] <= h[1];
      t[2] <= t[2]; h[2] <= h[2];
      t[3] <= t[3]; h[3] <= h[3];
      t[4] <= t[4]; h[4] <= h[4];
      t[5] <= t[5]; h[5] <= h[5];
      t[6] <= t[6]; h[6] <= h[6];
      t[7] <= t[7]; h[7] <= h[7];
    end
  end

  // Sorting temp buffers update
  always @(posedge clk) begin
    t_tmp[0] <= t[0]; h_tmp[0] <= h[0];
    t_tmp[1] <= t[1]; h_tmp[1] <= h[1];
    t_tmp[2] <= t[2]; h_tmp[2] <= h[2];
    t_tmp[3] <= t[3]; h_tmp[3] <= h[3];
    t_tmp[4] <= t[4]; h_tmp[4] <= h[4];
    t_tmp[5] <= t[5]; h_tmp[5] <= h[5];
    t_tmp[6] <= t[6]; h_tmp[6] <= h[6];
    t_tmp[7] <= t[7]; h_tmp[7] <= h[7];
  end

  // Sorting pass and index control
  always @(posedge clk) begin
    if (state == IDLE) begin
      pass      <= 4'd0;
      j         <= 4'd0;
      swapped   <= 1'b0;
      sort_done <= 1'b0;
    end else if (state == SORT) begin
      if (j >= (n - 1 - pass)) begin
        j         <= 4'd0;
        if (swapped) begin
          pass <= pass + 1;
        end else begin
          sort_done <= 1'b1;
        end
        swapped   <= 1'b0;
      end else begin
        j <= j + 1;
      end
    end else begin
      pass      <= pass;
      j         <= j;
      swapped   <= swapped;
      sort_done <= sort_done;
    end
  end

  // Ripple sort: compare and swap adjacent elements on every cycle in SORT state
  integer k;
  always @(posedge clk) begin
    if (state == SORT) begin
      for (k = 0; k < NUM_STORES; k = k + 1) begin
        t_tmp[k] <= t_tmp[k];
        h_tmp[k] <= h_tmp[k];
      end
      if (j < (n - 1 - pass)) begin
        if (h_tmp[j] > h_tmp[j+1]) begin
          // Swap element j and j+1
          t_tmp[j]   <= h_tmp[j+1]; // temporary stores are updated in place
          h_tmp[j]   <= t_tmp[j+1]; // Note: t_tmp[j+1] is old t of j+1
          t_tmp[j+1] <= t_tmp[j];   // t_tmp[j] is old t of j (now holding old h)
          h_tmp[j+1] <= h_tmp[j];   // h_tmp[j] is old h of j+1
          swapped    <= 1'b1;
        end else begin
          swapped <= 1'b0;
        end
      end else begin
        swapped <= swapped;
      end
    end else begin
      for (k = 0; k < NUM_STORES; k = k + 1) begin
        t_tmp[k] <= t_tmp[k];
        h_tmp[k] <= h_tmp[k];
      end
      swapped <= 1'b0;
    end
  end

  // Commit sorted data to main buffers after each successful pass in SORT
  always @(posedge clk) begin
    if (state == SORT) begin
      if (j < (n - 1 - pass)) begin
        if (h_tmp[j] > h_tmp[j+1]) begin
          t[j]   <= t_tmp[j];
          h[j]   <= h_tmp[j];
          t[j+1] <= t_tmp[j+1];
          h[j+1] <= h_tmp[j+1];
        end else begin
          t[j]   <= t_tmp[j];
          h[j]   <= h_tmp[j];
          t[j+1] <= t_tmp[j+1];
          h[j+1] <= h_tmp[j+1];
        end
      end else begin
        t[0] <= t[0]; h[0] <= h[0];
        t[1] <= t[1]; h[1] <= h[1];
        t[2] <= t[2]; h[2] <= h[2];
        t[3] <= t[3]; h[3] <= h[3];
        t[4] <= t[4]; h[4] <= h[4];
        t[5] <= t[5]; h[5] <= h[5];
        t[6] <= t[6]; h[6] <= h[6];
        t[7] <= t[7]; h[7] <= h[7];
      end
    end else begin
      t[0] <= t[0]; h[0] <= h[0];
      t[1] <= t[1]; h[1] <= h[1];
      t[2] <= t[2]; h[2] <= h[2];
      t[3] <= t[3]; h[3] <= h[3];
      t[4] <= t[4]; h[4] <= h[4];
      t[5] <= t[5]; h[5] <= h[5];
      t[6] <= t[6]; h[6] <= h[6];
      t[7] <= t[7]; h[7] <= h[7];
    end
  end

  // Accumulator state
  always @(posedge clk) begin
    if (state == IDLE) begin
      total_time <= 16'd0;
      i          <= 4'd0;
      acc_count  <= 4'd0;
    end else if (state == ACCUMULATE) begin
      if (i < n) begin
        if ((total_time + t[i]) <= h[i]) begin
          total_time <= total_time + t[i];
          acc_count  <= acc_count + 1;
          i          <= i + 1;
        end else begin
          // Cannot add this store; stop accumulating
          i <= n; // will exit loop next cycle
        end
      end else begin
        total_time <= total_time;
        acc_count  <= acc_count;
        i          <= i;
      end
    end else begin
      total_time <= total_time;
      i          <= i;
      acc_count  <= acc_count;
    end
  end

  // State register
  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = SORT;
        else       next_state = IDLE;
      end
      SORT: begin
        if (sort_done || pass >= (n - 1)) next_state = ACCUMULATE;
        else                               next_state = SORT;
      end
      ACCUMULATE: begin
        if (i >= n) next_state = DONE;
        else        next_state = ACCUMULATE;
      end
      DONE: begin
        if (start) next_state = SORT;
        else       next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Output updates
  always @(posedge clk) begin
    if (!rst_n) begin
      max_count <= 4'd0;
      done      <= 1'b1;
    end else begin
      case (state)
        IDLE: begin
          max_count <= 4'd0;
          done      <= ~start; // done high until start pulses
        end
        SORT: begin
          max_count <= 4'd0;
          done      <= 1'b0;
        end
        ACCUMULATE: begin
          max_count <= 4'd0;
          done      <= 1'b0;
        end
        DONE: begin
          max_count <= acc_count;
          done      <= 1'b1; // stays high until reset or new start
        end
        default: begin
          max_count <= 4'd0;
          done      <= 1'b1;
        end
      endcase
    end
  end

endmodule