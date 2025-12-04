module mps_receiver(
  input clk,
  input rst_n,
  input start,
  input [1:0] beacon_count,
  input [9:0] x[0:3],
  input [9:0] y[0:3],
  input [11:0] d[0:3],
  output reg [9:0] x_r,
  output reg [9:0] y_r,
  output reg [1:0] status
);

  reg [9:0] x_cand;
  reg [9:0] first_x, first_y;
  reg [19:0] valid_count;
  reg found_once;
  reg found_multi;

  typedef enum logic [1:0] {
    IDLE,
    SEARCH,
    DONE
  } state_t;

  state_t state;

  // dx calculations for all beacons
  logic [11:0] dx[0:3];
  logic [9:0] first_y_in_x;
  logic [10:0] count_valid_in_x;
  logic any_valid;
  logic multi_valid;

  always @(*) begin
    for (int i=0; i<4; i=i+1) begin
      dx[i] = (x_cand >= x[i]) ? (x_cand - x[i]) : (x[i] - x_cand);
    end
  end

  always @(*) begin
    count_valid_in_x = 0;
    any_valid = 0;
    multi_valid = 0;
    first_y_in_x = 0;

    reg first_found_in_x = 0;
    for (int y_val=-512; y_val<=511; y_val=y_val+1) begin
      logic valid_for_y = 1;
      for (int i=0; i<=(beacon_count); i++) begin
        logic [9:0] y_i = y[i];
        logic [10:0] diff = (y_val > y_i) ? y_val - y_i : y_i - y_val;
        logic [12:0] sum = dx[i] + diff;
        if (sum != d[i]) valid_for_y = 0;
      end

      if (valid_for_y) begin
        count_valid_in_x = count_valid_in_x + 1;
        if (!first_found_in_x) begin
          first_found_in_x = 1;
          first_y_in_x = y_val;
        end
        if (first_found_in_x && (count_valid_in_x > 1)) multi_valid = 1;
      end
    end
    any_valid = (count_valid_in_x > 0);
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      x_cand <= 10'sh200;
      valid_count <= 0;
      found_once <= 0;
      found_multi <= 0;
      first_x <= 0;
      first_y <= 0;
      x_r <= 0;
      y_r <= 0;
      status <= 2'b00;
    end else begin
      case(state)
        IDLE: begin
          status <= 2'b00;
          if (start) begin
            state <= SEARCH;
            x_cand <= 10'sh200;
            valid_count <= 0;
            found_once <= 0;
            found_multi <= 0;
          end
        end
        SEARCH: begin
          if (any_valid) begin
            valid_count <= valid_count + count_valid_in_x;
            if (!found_once) begin
              found_once <= 1'b1;
              first_x <= x_cand;
              first_y <= first_y_in_x;
              if (count_valid_in_x > 1) found_multi <= 1'b1;
            end else if (count_valid_in_x > 0) begin
              found_multi <= 1'b1;
            end
          end

          if (x_cand == 10'sh1FF) begin
            state <= DONE;
          end else begin
            x_cand <= x_cand + 1;
          end
        end
        DONE: begin
          if (!found_once) status <= 2'b11;
          else if (found_multi) status <= 2'b10;
          else begin
            status <= 2'b01;
            x_r <= first_x;
            y_r <= first_y;
          end
          if (!start) state <= IDLE;
        end
      endcase
    end
  end
endmodule