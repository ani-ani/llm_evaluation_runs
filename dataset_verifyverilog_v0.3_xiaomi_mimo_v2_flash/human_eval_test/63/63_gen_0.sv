module fibfib(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] CHECK_BASE  = 3'd1;
    localparam [2:0] INIT_LOOP   = 3'd2;
    localparam [2:0] ITERATE     = 3'd3;
    localparam [2:0] FINISHED    = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [4:0] counter;
    reg [31:0] f0;
    reg [31:0] f1;
    reg [31:0] f2;
    reg [4:0] n_reg;
    reg base_case_handled;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            counter <= 5'd0;
            f0 <= 32'd0;
            f1 <= 32'd0;
            f2 <= 32'd0;
            n_reg <= 5'd0;
            base_case_handled <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 5'd0;
                    base_case_handled <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        state <= CHECK_BASE;
                    end
                end

                CHECK_BASE: begin
                    if (n_reg == 5'd0 || n_reg == 5'd1) begin
                        result <= 32'd0;
                        state <= FINISHED;
                    end else if (n_reg == 5'd2) begin
                        result <= 32'd1;
                        state <= FINISHED;
                    end else begin
                        state <= INIT_LOOP;
                    end
                end

                INIT_LOOP: begin
                    f0 <= 32'd0;  // fibfib(0)
                    f1 <= 32'd0;  // fibfib(1)
                    f2 <= 32'd1;  // fibfib(2)
                    counter <= 5'd3;
                    state <= ITERATE;
                end

                ITERATE: begin
                    // fibfib(i) = f0 + f1 + f2
                    // f0 becomes f1, f1 becomes f2, f2 becomes result
                    // For i=3: f0=0, f1=0, f2=1 -> f3=1
                    f0 <= f1;
                    f1 <= f2;
                    f2 <= f0 + f1 + f2;
                    counter <= counter + 5'd1;
                    
                    if (counter >= n_reg) begin
                        result <= f2;
                        state <= FINISHED;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule