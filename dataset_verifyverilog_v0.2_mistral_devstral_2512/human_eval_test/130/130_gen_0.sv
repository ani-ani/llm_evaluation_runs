module tribonacci (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [31:0] result,
    output reg valid,
    output reg busy
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        COMPUTE,
        DONE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [31:0] tri [0:10];
    reg [3:0] count;
    reg [31:0] temp_result;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 1'b0;
            valid <= 1'b0;
            count <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end
            end
            COMPUTE: begin
                if (count == n) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
            busy <= 1'b0;
            valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    valid <= 1'b0;
                end
                COMPUTE: begin
                    busy <= 1'b1;
                    valid <= 1'b0;
                end
                DONE: begin
                    busy <= 1'b0;
                    valid <= 1'b1;
                    result <= temp_result;
                end
                default: begin
                    busy <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end

    // Compute logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 4'd0;
            temp_result <= 32'd0;
            for (int i = 0; i < 11; i = i + 1) begin
                tri[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        count <= 4'd0;
                        // Initialize base cases
                        tri[0] <= 16'd1 << 16; // 1.0 in Q16.16
                        tri[1] <= 16'd3 << 16; // 3.0 in Q16.16
                        tri[2] <= 16'd2 << 16; // 2.0 in Q16.16
                    end
                end
                COMPUTE: begin
                    if (count < n) begin
                        if (count[0] == 1'b0) begin // Even
                            tri[count] <= (16'd1 + (count >> 1)) << 16;
                        end else begin // Odd
                            tri[count] <= tri[count-1] + tri[count-2] + tri[count+1];
                        end
                        count <= count + 1'b1;
                    end else begin
                        temp_result <= tri[n];
                    end
                end
                DONE: begin
                    // No action needed
                end
                default: begin
                    // No action needed
                end
            endcase
        end
    end

endmodule