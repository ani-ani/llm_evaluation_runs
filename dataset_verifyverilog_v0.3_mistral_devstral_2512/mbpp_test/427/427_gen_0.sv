module DateFormatConverter(
    input clk,
    input rst_n,
    input start,
    input [7:0] date_in [0:9],
    output reg [7:0] date_out [0:9],
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CONVERT = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            for (i = 0; i < 10; i = i + 1) begin
                date_out[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CONVERT;
                    end
                end
                
                CONVERT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Rearrange characters: yyyy-mm-dd -> dd-mm-yyyy
                    date_out[0] <= date_in[8];  // d
                    date_out[1] <= date_in[9];  // d
                    date_out[2] <= 8'd45;      // '-'
                    date_out[3] <= date_in[5];  // m
                    date_out[4] <= date_in[6];  // m
                    date_out[5] <= 8'd45;      // '-'
                    date_out[6] <= date_in[0];  // y
                    date_out[7] <= date_in[1];  // y
                    date_out[8] <= date_in[2];  // y
                    date_out[9] <= date_in[3];  // y
                    
                    if (cycle_count >= MAX_CYCLES - 8'd1) begin
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule