module square_perimeter(
    input clk,
    input rst_n,
    input [7:0] side_in,
    input start,
    output reg [15:0] perimeter_out,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state;
    reg [15:0] perimeter_next;

    // Combinational perimeter calculation
    assign perimeter_next = side_in * 4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            perimeter_out <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    perimeter_out <= perimeter_next;
                    state <= DONE_STATE;
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