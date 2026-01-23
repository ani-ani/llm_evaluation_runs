module art_dealer_count (
    input clk,
    input rst_n,
    input start,
    input [7:0] client_idx,
    input [7:0] a_in,
    input [7:0] b_in,
    output reg [15:0] result,
    output reg done,
    output reg error
);

    // Parameters
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam DONE = 3'b100;
    localparam MOD = 16'd10007;
    localparam N = 8;

    // State register
    reg [2:0] state, next_state;

    // Client data storage
    reg [7:0] a [0:N-1];
    reg [7:0] b [0:N-1];
    reg [7:0] load_count;

    // Intermediate computation registers
    reg [31:0] prod_ab;
    reg [31:0] prod_b;
    reg [31:0] sum_a_prod_b;
    reg [31:0] temp_prod;
    reg [31:0] temp_sum;
    reg [7:0] compute_count;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_count <= 0;
            compute_count <= 0;
            prod_ab <= 0;
            prod_b <= 0;
            sum_a_prod_b <= 0;
            temp_prod <= 0;
            temp_sum <= 0;
            result <= 0;
            done <= 0;
            error <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: begin
                if (load_count == N-1) next_state = COMPUTE;
            end
            COMPUTE: begin
                if (compute_count == N-1) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Load data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_count <= 0;
        end else if (state == LOAD) begin
            if (client_idx < N) begin
                a[client_idx] <= a_in;
                b[client_idx] <= b_in;
                load_count <= load_count + 1;
            end
        end
    end

    // Compute logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            compute_count <= 0;
            prod_ab <= 1;
            prod_b <= 1;
            sum_a_prod_b <= 0;
            temp_prod <= 1;
            temp_sum <= 0;
        end else if (state == COMPUTE) begin
            if (compute_count == 0) begin
                // Initialize products
                prod_ab <= (a[0] + b[0]) % MOD;
                prod_b <= b[0] % MOD;
                temp_prod <= 1;
                temp_sum <= 0;
                compute_count <= compute_count + 1;
            end else begin
                // Update prod_ab and prod_b
                prod_ab <= (prod_ab * ((a[compute_count] + b[compute_count]) % MOD)) % MOD;
                prod_b <= (prod_b * (b[compute_count] % MOD)) % MOD;

                // Compute temp_prod (product of b_j for j != i)
                if (compute_count == 1) begin
                    temp_prod <= b[0] % MOD;
                end else begin
                    temp_prod <= (temp_prod * (b[compute_count-1] % MOD)) % MOD;
                end

                // Update sum_a_prod_b
                if (compute_count == N-1) begin
                    temp_sum <= (temp_sum + (a[compute_count] % MOD) * (temp_prod % MOD)) % MOD;
                    sum_a_prod_b <= temp_sum;
                end else begin
                    temp_sum <= (temp_sum + (a[compute_count-1] % MOD) * (temp_prod % MOD)) % MOD;
                end

                compute_count <= compute_count + 1;
            end
        end
    end

    // Final result calculation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
        end else if (state == DONE) begin
            result <= (prod_ab - prod_b - sum_a_prod_b) % MOD;
            done <= 1;
        end else begin
            done <= 0;
        end
    end

    // Error detection (invalid state)
    always @(*) begin
        error = (state == 3'b111);
    end

endmodule