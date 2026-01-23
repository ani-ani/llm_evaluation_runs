module strlen(
    input clk,
    input rst_n,
    input start,
    input [7:0] string [0:15],
    output reg [4:0] length,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COUNTING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] position;  // 4 bits for 0-15
    reg [4:0] counter;   // 5 bits for 0-16
    reg [7:0] current_byte;
    reg [7:0] cycle_count;  // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd20;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            position <= 4'd0;
            counter <= 5'd0;
            current_byte <= 8'd0;
            cycle_count <= 8'd0;
            length <= 5'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COUNTING;
                end else begin
                    next_state = IDLE;
                end
            end

            COUNTING: begin
                if (current_byte == 8'd0 || cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = COUNTING;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            position <= 4'd0;
            counter <= 5'd0;
            current_byte <= 8'd0;
            cycle_count <= 8'd0;
            length <= 5'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    position <= 4'd0;
                    counter <= 5'd0;
                end

                COUNTING: begin
                    cycle_count <= cycle_count + 8'd1;
                    current_byte <= string[position];
                    if (current_byte == 8'd0) begin
                        length <= counter;
                    end else begin
                        position <= position + 4'd1;
                        counter <= counter + 5'd1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    length <= counter;
                end

                default: begin
                    position <= 4'd0;
                    counter <= 5'd0;
                    current_byte <= 8'd0;
                    cycle_count <= 8'd0;
                    length <= 5'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule