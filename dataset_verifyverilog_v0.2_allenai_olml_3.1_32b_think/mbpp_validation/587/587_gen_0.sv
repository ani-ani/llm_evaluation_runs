module list_to_tuple (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_elements,
    input [7:0] list_in [0:7],
    output reg [7:0] tuple_out [0:7],
    output reg done,
    output reg valid
);

localparam IDLE = 3'd0;
localparam PROCESSING = 3'd1;
localparam DONE = 3'd2;

reg [2:0] state;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        tuple_out[0] <= 8'd0;
        tuple_out[1] <= 8'd0;
        tuple_out[2] <= 8'd0;
        tuple_out[3] <= 8'd0;
        tuple_out[4] <= 8'd0;
        tuple_out[5] <= 8'd0;
        tuple_out[6] <= 8'd0;
        tuple_out[7] <= 8'd0;
        done <= 1'b0;
        valid <= 1'b0;
    end else begin
        case (state) 
            IDLE: 
                if (start) 
                    state <= PROCESSING;
                else 
                    state <= IDLE;
                done <= 1'b0;
                valid <= 1'b0;
            PROCESSING: 
                tuple_out[0] = list_in[0];
                tuple_out[1] = (num_elements > 1) ? list_in[1] : 8'd0;
                tuple_out[2] = (num_elements > 2) ? list_in[2] : 8'd0;
                tuple_out[3] = (num_elements > 3) ? list_in[3] : 8'd0;
                tuple_out[4] = (num_elements > 4) ? list_in[4] : 8'd0;
                tuple_out[5] = (num_elements > 5) ? list_in[5] : 8'd0;
                tuple_out[6] = (num_elements > 6) ? list_in[6] : 8'd0;
                tuple_out[7] = (num_elements > 7) ? list_in[7] : 8'd0;
                state <= DONE;
                done <= 1'b1;
                valid <= 1'b1;
            DONE: 
                state <= DONE;
                done <= 1'b1;
                valid <= 1'b1;
            default: state <= IDLE;
        endcase
    end
endmodule