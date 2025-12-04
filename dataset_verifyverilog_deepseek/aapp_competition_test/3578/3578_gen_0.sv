module airline_review_cost(
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [2:0] R,
  input [2:0] F,
  input [5:0][13:0] req_flights,
  input [5:0][13:0] add_flights,
  output reg [16:0] minimal_cost,
  output reg done
);
  localparam IDLE = 3'd0;
  localparam SUM_REQ_CALC = 3'd1;
  localparam BUILD_GRAPH = 3'd2;
  localparam PRIM_MST = 3'd3;
  localparam COMPLETE = 3'd4;

  reg [2:0] state;
  reg [16:0] sum_req_cost;
  reg [7:0] required_airports;
  reg [2:0] counter;
  reg [13:0] adj_matrix [0:7][0:7];
  reg [7:0] visited;
  reg [13:0] key [0:7];
  reg [16:0] mst_cost;
  wire all_required_visited = (visited & required_airports) == required_airports;
  integer i, j;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      sum_req_cost <= 0;
      minimal_cost <= 0;
      required_airports <= 8'd0;
      mst_cost <= 0;
      counter <= 0;
      for (i = 0; i < 8; i++) begin
        key[i] <= 14'h3FFF;
        visited[i] <= 1'b0;
        for (j = 0; j < 8; j++)
          adj_matrix[i][j] <= 14'h3FFF;
      end
    end
    else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= SUM_REQ_CALC;
            sum_req_cost <= 0;
            required_airports <= 8'd0;
            counter <= 0;
          end
        end

        SUM_REQ_CALC: begin
          if (counter < R) begin
            reg [3:0] a, b;
            reg [5:0] c;
            a = req_flights[counter][13:10];
            b = req_flights[counter][9:6];
            c = req_flights[counter][5:0];
            if (a <= N && b <= N && a != 0 && b != 0) begin
              sum_req_cost <= sum_req_cost + {11'd0, c};
              required_airports <= required_airports | (1 << (a-1)) | (1 << (b-1));
            end
            counter <= counter + 1;
          end
          else begin
            state <= BUILD_GRAPH;
            counter <= 0;
            for (i = 0; i < 8; i++) for (j = 0; j < 8; j++)
              adj_matrix[i][j] <= 14'h3FFF;
          end
        end

        BUILD_GRAPH: begin
          if (counter < R + F) begin
            reg [3:0] a, b;
            reg [5:0] c;
            case (counter < R)
              1'b1: {a, b, c} = {req_flights[counter][13:10], req_flights[counter][9:6], req_flights[counter][5:0]};
              1'b0: {a, b, c} = {add_flights[counter - R][13:10], add_flights[counter - R][9:6], add_flights[counter - R][5:0]};
            endcase
            if (a <= N && b <= N && a != 0 && b != 0) begin
              int ai = a-1, bi = b-1;
              if ({8'd0, c} < adj_matrix[ai][bi]) begin
                adj_matrix[ai][bi] <= {8'd0, c};
                adj_matrix[bi][ai] <= {8'd0, c};
              end
            end
            counter <= counter + 1;
          end
          else begin
            state <= PRIM_MST;
            mst_cost <= 0;
            visited <= 8'd0;
            for (i = 0; i < 8; i++) key[i] <= 14'h3FFF;
            for (i = 0; i < 8; i++) begin
              if (required_airports[i]) begin
                key[i] <= 0;
                break;
              end
            end
          end
        end

        PRIM_MST: begin
          if (required_airports != 0 && !all_required_visited) begin
            integer min_index;
            reg [13:0] min_key;
            min_key = 14'h3FFF;
            min_index = 0;
            for (i = 0; i < 8; i++) begin
              if (!visited[i] && key[i] < min_key) begin
                min_key = key[i];
                min_index = i;
              end
            end
            visited[min_index] <= 1'b1;
            mst_cost <= mst_cost + key[min_index];
            for (j = 0; j < 8; j++) begin
              if (!visited[j] && adj_matrix[min_index][j] < key[j])
                key[j] <= adj_matrix[min_index][j];
            end
          end
          else
            state <= COMPLETE;
        end

        COMPLETE: begin
          minimal_cost <= sum_req_cost + mst_cost;
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule