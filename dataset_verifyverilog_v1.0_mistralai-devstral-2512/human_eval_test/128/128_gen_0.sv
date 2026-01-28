module prod_signs(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:7],
    input wire [2:0] len,
    output reg signed [15:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE    = 2'd2;

    // Registers
    reg [1:0] state;
    reg [1:0] sign_prod;
    reg signed [15:0] mag_sum;
    reg [2:0] idx;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    // Sign extraction and magnitude calculation
    wire signed [7:0] current_elem;
    wire signed [1:0] current_sign;
    wire signed [7:0] current_mag;

    assign current_elem = arr[idx];
    assign current_sign = (current_elem == 8'd0) ? 2'd0 : 
                         (current_elem[7] == 1'b0) ? 2'd1 : 2'd3; // 2'd3 = -1 in 2's complement
    assign current_mag = (current_elem[7] == 1'b0) ? current_elem : (~current_elem + 8'd1);

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (len == 3'd0) begin
                        state = DONE;
                    end else begin
                        state = PROCESS;
                    end
                end else begin
                    state = IDLE;
                end
            end
            PROCESS: begin
                if (idx == (len - 1)) begin
                    state = DONE;
                end else begin
                    state = PROCESS;
                end
            end
            DONE: begin
                state = IDLE;
            end
            default: state = IDLE;
        endcase
    end

    // Register updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sign_prod <= 2'd0;
            mag_sum <= 16'd0;
            idx <= 3'd0;
            result <= 16'd0;
            done <= 1'b0;
            valid <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        sign_prod <= 2'd1; // Initialize to 1
                        mag_sum <= 16'd0;
                        idx <= 3'd0;
                    end
                end
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Update sign product
                    if (current_elem == 8'd0) begin
                        sign_prod <= 2'd0;
                    end else if (sign_prod == 2'd0) begin
                        sign_prod <= 2'd0;
                    end else begin
                        sign_prod <= sign_prod * current_sign;
                    end
                    
                    // Update magnitude sum
                    mag_sum <= mag_sum + {{8'd0}, current_mag};
                    
                    // Update index
                    if (idx == (len - 1)) begin
                        idx <= 3'd0;
                    end else begin
                        idx <= idx + 3'd1;
                    end
                end
                DONE: begin
                    if (len == 3'd0) begin
                        result <= 16'd0;
                        valid <= 1'b0;
                    end else begin
                        // Final multiplication: sign_prod (2-bit) * mag_sum (16-bit)
                        // Sign extend sign_prod to 16 bits
                        wire signed [15:0] sign_extended = {{14{sign_prod[1]}}, sign_prod};
                        result <= sign_extended * mag_sum;
                        valid <= 1'b1;
                    end
                    done <= 1'b1;
                    
                    // Safety: return to IDLE
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end
                default: begin
                    state <= IDLE;
                    sign_prod <= 2'd0;
                    mag_sum <= 16'd0;
                    idx <= 3'd0;
                    result <= 16'd0;
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end
endmodule