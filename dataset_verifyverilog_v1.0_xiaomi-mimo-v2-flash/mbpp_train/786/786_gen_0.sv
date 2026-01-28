module binary_search_bisect_right (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [7:0] val,
    input wire [3:0] len,
    output reg [3:0] index,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SEARCH = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Registers
    reg [1:0] state;
    reg [3:0] low;
    reg [3:0] high;
    reg [3:0] mid;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15; // 16 elements max

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            done <= 1'b0;
            low <= 4'd0;
            high <= 4'd0;
            mid <= 4'd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        low <= 4'd0;
                        high <= len;
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    if (low < high) begin
                        mid <= (low + high) >> 1; // (low + high) / 2
                        cycle_count <= cycle_count + 4'd1;
                        
                        if (arr[mid] <= val) begin
                            low <= mid + 4'd1;
                        end else begin
                            high <= mid;
                        end
                    end else begin
                        // low >= high, search complete
                        state <= FINISH;
                        index <= low;
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        // Safety timeout
                        state <= FINISH;
                        index <= low;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule