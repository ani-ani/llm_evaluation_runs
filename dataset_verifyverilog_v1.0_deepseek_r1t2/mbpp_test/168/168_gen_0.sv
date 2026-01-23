module frequency_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] arr_len,
    input wire [7:0] target,
    output reg [7:0] count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COUNTING = 3'd1;
    localparam [2:0] COMPLETE = 3'd2;
    
    reg [2:0] state;
    reg [3:0] idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 8'd0;
            idx <= 4'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    count <= 8'd0;
                    idx <= 4'd0;
                    if (start) begin
                        state <= COUNTING;
                    end
                end
                
                COUNTING: begin
                    if (idx < arr_len) begin
                        if (arr[idx] == target) begin
                            count <= count + 8'd1;
                        end
                        idx <= idx + 4'd1;
                    end else begin
                        state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule