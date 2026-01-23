module lights_controller(input clk, input rst_n, input start, input [15:0] initial_states, input [4:0] a [15:0], input [4:0] b [15:0], output reg [4:0] max_lights, output reg done);
reg [15:0] current_states;
reg [4:0] max_lights;
reg [5:0] t_count;
reg [2:0] state;

assign mask = 0;
genvar i;
generate
   for (i=0; i<16; i++) begin
      if ( (t_count >= b[i]) && (a[i]) && ( (t_count - b[i]) % a[i] ==0 ) ) begin
          mask |= (1 << i);
      end
   end
endgenerate

assign current_count = 0;
generate
   for (i=0; i<16; i++) begin
      current_count = current_count + current_states[i];
   end
endgenerate

assign done = (state == 3'b2);

always @(posedge clk) begin
    if (!rst_n) begin
        current_states <= 16'b0;
        max_lights <= 5'b0;
        t_count <= 6'b0;
        state <= 3'b0;
    end else begin
        if (state == 3'b0) begin // IDLE
            if (start) begin
                current_states <= initial_states;
                max_lights <= 5'b0;
                t_count <= 6'b0;
                state <= 3'b1;
            end
        end else if (state == 3'b1) begin // CALCULATING
            if (t_count < 64) begin
                current_states <= current_states ^ mask;
                if (current_count > max_lights) begin
                    max_lights <= current_count;
                end
                t_count <= t_count + 1;
            end else begin
                state <= 3'b2;
            end
        end
    end
end
endmodule