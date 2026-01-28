module parity_checker(
    input clk,
    input rst_n,
    input start,
    input [15:0] num,
    output reg parity,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [15:0] shift_reg;
    reg [3:0] counter;
    reg parity_acc;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            shift_reg <= 16'd0;
            counter <= 4'd0;
            parity_acc <= 1'b0;
            parity <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                next_state = IDLE;
                done = 1'b0;
                if (start) begin
                    next_state = COMPUTE;
                end
            end

            COMPUTE: begin
                next_state = COMPUTE;
                done = 1'b0;
                if (counter == 4'd15) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
                done = 1'b1;
            end

            default: begin
                next_state = IDLE;
                done = 1'b0;
            end
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 16'd0;
            counter <= 4'd0;
            parity_acc <= 1'b0;
            parity <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        shift_reg <= num;
                        counter <= 4'd0;
                        parity_acc <= 1'b0;
                    end
                end

                COMPUTE: begin
                    // Shift right by 1
                    shift_reg <= {1'b0, shift_reg[15:1]};
                    
                    // XOR current LSB with accumulator
                    parity_acc <= parity_acc ^ shift_reg[0];
                    
                    // Increment counter
                    counter <= counter + 4'd1;
                    
                    // Output parity when done
                    if (counter == 4'd15) begin
                        parity <= parity_acc;
                    end
                end

                DONE_STATE: begin
                    // Hold parity for one cycle
                    parity <= parity_acc;
                end

                default: begin
                    shift_reg <= 16'd0;
                    counter <= 4'd0;
                    parity_acc <= 1'b0;
                    parity <= 1'b0;
                end
            endcase
        end
    end

endmodule