module compute_diff (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] COMPUTE   = 2'd1;
    localparam [1:0] FINISH    = 2'd2;

    // Internal registers and wires
    reg [1:0] state, next_state;
    reg [2:0] counter;
    reg [7:0] min_reg;
    reg [7:0] max_reg;
    reg [7:0] current_val;
    reg [7:0] new_min;
    reg [7:0] new_max;
    wire cmp_min;
    wire cmp_max;
    reg cycle_done;

    // Combinational logic for comparisons
    assign cmp_min = (current_val < min_reg);
    assign cmp_max = (current_val > max_reg);

    // Update min and max logic
    always @(*) begin
        new_min = cmp_min ? current_val : min_reg;
        new_max = cmp_max ? current_val : max_reg;
    end

    // Determine when computation cycle is complete
    always @(*) begin
        if (counter == 3'd7) begin
            cycle_done = 1'b1;
        end else begin
            cycle_done = 1'b0;
        end
    end

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = IDLE;
                end
            end
            COMPUTE: begin
                if (cycle_done) begin
                    next_state = FINISH;
                end else begin
                    next_state = COMPUTE;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            counter <= 3'd0;
            min_reg <= 8'd0;
            max_reg <= 8'd0;
            current_val <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 3'd0;
                    if (start) begin
                        // Initialize min and max with first element
                        min_reg <= arr[0];
                        max_reg <= arr[0];
                        current_val <= arr[0];
                        counter <= 3'd1;
                    end
                end
                COMPUTE: begin
                    // Update min and max
                    min_reg <= new_min;
                    max_reg <= new_max;
                    
                    // Load next element
                    if (!cycle_done) begin
                        current_val <= arr[counter + 3'd1];
                        counter <= counter + 3'd1;
                    end
                end
                FINISH: begin
                    // Compute final result
                    result <= {8'd0, max_reg} - {8'd0, min_reg};
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                    counter <= 3'd0;
                    min_reg <= 8'd0;
                    max_reg <= 8'd0;
                    current_val <= 8'd0;
                    result <= 16'd0;
                    done <= 1'b0;
                end
            endcase
            
            // Update state
            state <= next_state;
        end
    end

endmodule