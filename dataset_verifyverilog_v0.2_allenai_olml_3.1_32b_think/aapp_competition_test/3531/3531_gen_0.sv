module constrained_mst(input clk, input rst_n, input start, input [3:0] n, input [3:0] m, input [3:0] k, input [3:0] w, input [15:0] special_nodes_mask, input [15:0] edge_node_a [0:15], input [15:0] edge_node_b [0:15], input [15:0] edge_cost [0:15], output reg [31:0] result, output reg done);

reg [31:0] min_cost;
reg [15:0] counter;
reg [2:0] state;

// Initialize
always @(posedge clk or !rst_n) begin
  if (!rst_n) begin
    min_cost <= 32'hFFFFFFFF;
    counter <= 0;
    state <= 0;
    done <= 1'b0;
    result <= 32'h0;
  end else begin
    if (state == 0) begin // IDLE
      if (start) begin
        counter <= counter + 1;
        state <= 1;
      end
    end
  end
end

// Check completion
always @(*) begin
  done = (state == 2);
end

// Transition to DONE
always @(posedge clk) begin
  if (state == 1 && counter > (1<<m)-1) begin
    state <= 2;
    if (min_cost == 32'hFFFFFFFF) begin
      result <= 32'hFFFFFFFF;
    end else begin
      result <= min_cost;
    end
  end
end

endmodule