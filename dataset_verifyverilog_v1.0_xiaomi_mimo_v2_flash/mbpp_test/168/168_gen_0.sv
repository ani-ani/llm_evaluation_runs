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

// State machine states
reg [1:0] state;
localparam [1:0] IDLE = 2'd0;
localparam [1:0] COUNTING = 2'd1;
localparam [1:0] COMPLETE = 2'd2;

// Counter for array index
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
                if (start) begin
                    count <= 8'd0;
                    idx <= 4'd0;
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
                    done <= 1'b1;
                end
            end
            
            COMPLETE: begin
                done <= 1'b0;
                state <= IDLE;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule