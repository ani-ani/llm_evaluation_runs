module binary_search_left (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [7:0] x,
    input wire [3:0] len,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] CHECK     = 3'd2;
    localparam [2:0] COMPARE   = 3'd3;
    localparam [2:0] UPDATE    = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    // Registers
    reg [2:0] state;
    reg [3:0] low;
    reg [3:0] high;
    reg [3:0] mid;
    reg [7:0] arr_mid;
    reg [7:0] x_reg;
    reg [3:0] len_reg;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            low <= 4'd0;
            high <= 4'd0;
            mid <= 4'd0;
            arr_mid <= 8'd0;
            x_reg <= 8'd0;
            len_reg <= 4'd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        x_reg <= x;
                        len_reg <= len;
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize low=0, high=len
                    low <= 4'd0;
                    high <= len_reg;
                    cycle_count <= cycle_count + 4'd1;
                    
                    if (len_reg == 4'd0) begin
                        // Empty array, result is 0
                        result <= 4'd0;
                        state <= FINISH;
                    end else begin
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    // Check termination condition: low >= high
                    cycle_count <= cycle_count + 4'd1;
                    
                    if (low >= high) begin
                        result <= low;
                        state <= FINISH;
                    end else begin
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    // Compute mid = (low + high) >> 1
                    mid <= (low + high) >> 1;
                    cycle_count <= cycle_count + 4'd1;
                    state <= UPDATE;
                end

                UPDATE: begin
                    // Load arr[mid] and compare
                    arr_mid <= arr[mid];
                    cycle_count <= cycle_count + 4'd1;
                    
                    if (arr[mid] >= x_reg) begin
                        // arr[mid] >= x, search left half
                        high <= mid;
                    end else begin
                        // arr[mid] < x, search right half
                        low <= mid + 4'd1;
                    end
                    state <= CHECK;
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