module binary_search(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [7:0] val,
    input wire [3:0] len,
    output reg [3:0] index,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] SEARCH  = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [3:0] low;
    reg [3:0] high;
    reg [3:0] mid;
    reg [7:0] arr_mid;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd64;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            done <= 1'b0;
            low <= 4'd0;
            high <= 4'd0;
            mid <= 4'd0;
            arr_mid <= 8'd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= SEARCH;
                        low <= 4'd0;
                        high <= len;
                    end
                end
                
                SEARCH: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Binary search logic
                    if (low < high) begin
                        mid <= (low + high) >> 1;
                        arr_mid <= arr[mid];
                        
                        if (arr_mid <= val) begin
                            low <= mid + 4'd1;
                        end else begin
                            high <= mid;
                        end
                    end else begin
                        state <= FINISH;
                    end
                    
                    // Prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    index <= low;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule