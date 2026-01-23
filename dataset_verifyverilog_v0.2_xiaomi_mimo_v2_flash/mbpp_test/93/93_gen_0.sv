module power_calculator(
    input clk,
    input rst_n,
    input start,
    input [31:0] a,
    input [15:0] b,
    output reg [31:0] result,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam CHECK_ZERO = 3'b001;
    localparam CHECK_ONE = 3'b010;
    localparam COMPUTE = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state, next_state;
    reg [15:0] counter;
    reg [15:0] b_reg;
    reg [31:0] base_reg;
    
    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic & Output Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        done = 1'b0;
        
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = CHECK_ZERO;
                end
            end
            
            CHECK_ZERO: begin
                if (b_reg == 16'd0) begin
                    next_state = DONE;
                end else begin
                    next_state = CHECK_ONE;
                end
            end
            
            CHECK_ONE: begin
                if (b_reg == 16'd1) begin
                    next_state = DONE;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                if (counter == 16'd1) begin
                    next_state = DONE;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            DONE: begin
                done = 1'b1;
                if (!start) begin
                    next_state = IDLE;
                end else begin
                    next_state = DONE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
            counter <= 16'd0;
            b_reg <= 16'd0;
            base_reg <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        b_reg <= b;
                        base_reg <= a;
                        result <= 32'd1; // Initialize to 1
                        counter <= b;     // Initialize counter to b (acts as multiplier loop count)
                    end
                end
                
                CHECK_ZERO: begin
                    if (b_reg == 16'd0) begin
                        result <= 32'd1;
                    end
                end
                
                CHECK_ONE: begin
                    if (b_reg == 16'd1) begin
                        if (base_reg == 32'd0) begin
                            result <= 32'd0;
                        end else begin
                            result <= base_reg;
                        end
                    end else if (base_reg == 32'd0) begin
                        // If a=0 and b>1, result is 0
                        result <= 32'd0;
                    end
                    // Initialize for compute loop if needed
                    if (b_reg > 16'd1 && base_reg != 32'd0) begin
                        result <= base_reg;
                        counter <= b_reg - 16'd1;
                    end
                end
                
                COMPUTE: begin
                    if (counter > 16'd1) begin
                        result <= result * base_reg;
                        counter <= counter - 16'd1;
                    end
                end
                
                DONE: begin
                    // Hold result, assert done
                end
            endcase
        end
    end

endmodule