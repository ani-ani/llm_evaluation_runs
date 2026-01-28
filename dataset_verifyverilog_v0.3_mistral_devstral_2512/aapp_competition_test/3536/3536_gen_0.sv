module HeapProbability (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    input wire [31:0] b0, b1, b2, b3, b4, b5, b6, b7,
    input wire [7:0] p0, p1, p2, p3, p4, p5, p6, p7,
    output reg [31:0] result,
    output reg done
);

    parameter MAX_N = 8;
    parameter MOD = 1000000007;

    // State machine states
    localparam [2:0] S_IDLE = 3'd0;
    localparam [2:0] S_LOAD = 3'd1;
    localparam [2:0] S_BUILD = 3'd2;
    localparam [2:0] S_PROCESS = 3'd3;
    localparam [2:0] S_COMPUTE = 3'd4;
    localparam [2:0] S_DONE = 3'd5;
    reg [2:0] state;

    // Internal registers
    reg [7:0] node_counter;
    reg [7:0] child_counter;
    reg [7:0] poly_counter;
    reg [7:0] degree_counter;
    reg [31:0] b_values [0:MAX_N];
    reg [7:0] parent_idx [0:MAX_N];
    reg [7:0] children [0:MAX_N][0:MAX_N-1];
    reg [7:0] child_count [0:MAX_N];
    reg [31:0] poly_a [0:MAX_N];
    reg [31:0] poly_b [0:MAX_N];
    reg [31:0] poly_res [0:MAX_N];
    reg [31:0] poly_store [0:MAX_N][0:MAX_N];
    reg [31:0] inv_int [0:MAX_N+1];
    reg [31:0] temp_sum;
    reg [31:0] temp_mult;
    reg [31:0] temp_pow;
    reg [7:0] current_node;
    reg [7:0] current_child;
    reg [7:0] current_degree;
    reg [7:0] current_poly;
    reg [7:0] current_coeff;
    reg [7:0] current_exp;
    reg [7:0] current_inv;
    reg [7:0] current_b;
    reg [7:0] current_p;
    reg [7:0] current_k;
    reg [7:0] current_i;
    reg [7:0] current_j;
    reg [7:0] current_l;
    reg [7:0] current_m;
    reg [7:0] current_n;
    reg [7:0] current_o;
    reg [7:0] current_poly_idx;
    reg [7:0] current_poly_deg;
    reg [7:0] current_poly_coeff;
    reg [7:0] current_poly_exp;
    reg [7:0] current_poly_inv;
    reg [7:0] current_poly_b;
    reg [7:0] current_poly_p;
    reg [7:0] current_poly_k;
    reg [7:0] current_poly_i;
    reg [7:0] current_poly_j;
    reg [7:0] current_poly_l;
    reg [7:0] current_poly_m;
    reg [7:0] current_poly_n;
    reg [7:0] current_poly_o;
    reg [7:0] current_poly_idx2;
    reg [7:0] current_poly_deg2;
    reg [7:0] current_poly_coeff2;
    reg [7:0] current_poly_exp2;
    reg [7:0] current_poly_inv2;
    reg [7:0] current_poly_b2;
    reg [7:0] current_poly_p2;
    reg [7:0] current_poly_k2;
    reg [7:0] current_poly_i2;
    reg [7:0] current_poly_j2;
    reg [7:0] current_poly_l2;
    reg [7:0] current_poly_m2;
    reg [7:0] current_poly_n2;
    reg [7:0] current_poly_o2;
    reg [7:0] current_poly_idx3;
    reg [7:0] current_poly_deg3;
    reg [7:0] current_poly_coeff3;
    reg [7:0] current_poly_exp3;
    reg [7:0] current_poly_inv3;
    reg [7:0] current_poly_b3;
    reg [7:0] current_poly_p3;
    reg [7:0] current_poly_k3;
    reg [7:0] current_poly_i3;
    reg [7:0] current_poly_j3;
    reg [7:0] current_poly_l3;
    reg [7:0] current_poly_m3;
    reg [7:0] current_poly_n3;
    reg [7:0] current_poly_o3;
    reg [7:0] current_poly_idx4;
    reg [7:0] current_poly_deg4;
    reg [7:0] current_poly_coeff4;
    reg [7:0] current_poly_exp4;
    reg [7:0] current_poly_inv4;
    reg [7:0] current_poly_b4;
    reg [7:0] current_poly_p4;
    reg [7:0] current_poly_k4;
    reg [7:0] current_poly_i4;
    reg [7:0] current_poly_j4;
    reg [7:0] current_poly_l4;
    reg [7:0] current_poly_m4;
    reg [7:0] current_poly_n4;
    reg [7:0] current_poly_o4;
    reg [7:0] current_poly_idx5;
    reg [7:0] current_poly_deg5;
    reg [7:0] current_poly_coeff5;
    reg [7:0] current_poly_exp5;
    reg [7:0] current_poly_inv5;
    reg [7:0] current_poly_b5;
    reg [7:0] current_poly_p5;
    reg [7:0] current_poly_k5;
    reg [7:0] current_poly_i5;
    reg [7:0] current_poly_j5;
    reg [7:0] current_poly_l5;
    reg [7:0] current_poly_m5;
    reg [7:0] current_poly_n5;
    reg [7:0] current_poly_o5;
    reg [7:0] current_poly_idx6;
    reg [7:0] current_poly_deg6;
    reg [7:0] current_poly_coeff6;
    reg [7:0] current_poly_exp6;
    reg [7:0] current_poly_inv6;
    reg [7:0] current_poly_b6;
    reg [7:0] current_poly_p6;
    reg [7:0] current_poly_k6;
    reg [7:0] current_poly_i6;
    reg [7:0] current_poly_j6;
    reg [7:0] current_poly_l6;
    reg [7:0] current_poly_m6;
    reg [7:0] current_poly_n6;
    reg [7:0] current_poly_o6;
    reg [7:0] current_poly_idx7;
    reg [7:0] current_poly_deg7;
    reg [7:0] current_poly_coeff7;
    reg [7:0] current_poly_exp7;
    reg [7:0] current_poly_inv7;
    reg [7:0] current_poly_b7;
    reg [7:0] current_poly_p7;
    reg [7:0] current_poly_k7;
    reg [7:0] current_poly_i7;
    reg [7:0] current_poly_j7;
    reg [7:0] current_poly_l7;
    reg [7:0] current_poly_m7;
    reg [7:0] current_poly_n7;
    reg [7:0] current_poly_o7;
    reg [7:0] current_poly_idx8;
    reg [7:0] current_poly_deg8;
    reg [7:0] current_poly_coeff8;
    reg [7:0] current_poly_exp8;
    reg [7:0] current_poly_inv8;
    reg [7:0] current_poly_b8;
    reg [7:0] current_poly_p8;
    reg [7:0] current_poly_k8;
    reg [7:0] current_poly_i8;
    reg [7:0] current_poly_j8;
    reg [7:0] current_poly_l8;
    reg [7:0] current_poly_m8;
    reg [7:0] current_poly_n8;
    reg [7:0] current_poly_o8;
    reg [7:0] current_poly_idx9;
    reg [7:0] current_poly_deg9;
    reg [7:0] current_poly_coeff9;
    reg [7:0] current_poly_exp9;
    reg [7:0] current_poly_inv9;
    reg [7:0] current_poly_b9;
    reg [7:0] current_poly_p9;
    reg [7:0] current_poly_k9;
    reg [7:0] current_poly_i9;
    reg [7:0] current_poly_j9;
    reg [7:0] current_poly_l9;
    reg [7:0] current_poly_m9;
    reg [7:0] current_poly_n9;
    reg [7:0] current_poly_o9;

    // Precompute modular inverses
    initial begin
        inv_int[0] = 0;
        inv_int[1] = 1;
        inv_int[2] = 500000004;
        inv_int[3] = 333333336;
        inv_int[4] = 250000002;
        inv_int[5] = 400000003;
        inv_int[6] = 166666668;
        inv_int[7] = 142857144;
        inv_int[8] = 125000001;
        inv_int[9] = 111111112;
    end

    // Modular multiplication
    function automatic [31:0] mod_mult;
        input [31:0] a, b;
        reg [31:0] res;
    begin
        res = (a % MOD) * (b % MOD);
        if (res >= MOD) res = res % MOD;
        mod_mult = res;
    end
    endfunction

    // Modular exponentiation
    function automatic [31:0] mod_pow;
        input [31:0] base, exp;
        integer i;
        reg [31:0] res;
        reg [31:0] b;
        reg [31:0] e;
    begin
        res = 1;
        b = base % MOD;
        e = exp;
        for (i = 0; i < 32; i = i + 1) begin
            if (e[0]) res = mod_mult(res, b);
            b = mod_mult(b, b);
            e = e >> 1;
            if (e == 0) disable for_loop;
        end
        mod_pow = res;
    end
    endfunction

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0;
            result <= 0;
            node_counter <= 0;
            child_counter <= 0;
            poly_counter <= 0;
            degree_counter <= 0;
            current_node <= 0;
            current_child <= 0;
            current_degree <= 0;
            current_poly <= 0;
            current_coeff <= 0;
            current_exp <= 0;
            current_inv <= 0;
            current_b <= 0;
            current_p <= 0;
            current_k <= 0;
            current_i <= 0;
            current_j <= 0;
            current_l <= 0;
            current_m <= 0;
            current_n <= 0;
            current_o <= 0;
            current_poly_idx <= 0;
            current_poly_deg <= 0;
            current_poly_coeff <= 0;
            current_poly_exp <= 0;
            current_poly_inv <= 0;
            current_poly_b <= 0;
            current_poly_p <= 0;
            current_poly_k <= 0;
            current_poly_i <= 0;
            current_poly_j <= 0;
            current_poly_l <= 0;
            current_poly_m <= 0;
            current_poly_n <= 0;
            current_poly_o <= 0;
            current_poly_idx2 <= 0;
            current_poly_deg2 <= 0;
            current_poly_coeff2 <= 0;
            current_poly_exp2 <= 0;
            current_poly_inv2 <= 0;
            current_poly_b2 <= 0;
            current_poly_p2 <= 0;
            current_poly_k2 <= 0;
            current_poly_i2 <= 0;
            current_poly_j2 <= 0;
            current_poly_l2 <= 0;
            current_poly_m2 <= 0;
            current_poly_n2 <= 0;
            current_poly_o2 <= 0;
            current_poly_idx3 <= 0;
            current_poly_deg3 <= 0;
            current_poly_coeff3 <= 0;
            current_poly_exp3 <= 0;
            current_poly_inv3 <= 0;
            current_poly_b3 <= 0;
            current_poly_p3 <= 0;
            current_poly_k3 <= 0;
            current_poly_i3 <= 0;
            current_poly_j3 <= 0;
            current_poly_l3 <= 0;
            current_poly_m3 <= 0;
            current_poly_n3 <= 0;
            current_poly_o3 <= 0;
            current_poly_idx4 <= 0;
            current_poly_deg4 <= 0;
            current_poly_coeff4 <= 0;
            current_poly_exp4 <= 0;
            current_poly_inv4 <= 0;
            current_poly_b4 <= 0;
            current_poly_p4 <= 0;
            current_poly_k4 <= 0;
            current_poly_i4 <= 0;
            current_poly_j4 <= 0;
            current_poly_l4 <= 0;
            current_poly_m4 <= 0;
            current_poly_n4 <= 0;
            current_poly_o4 <= 0;
            current_poly_idx5 <= 0;
            current_poly_deg5 <= 0;
            current_poly_coeff5 <= 0;
            current_poly_exp5 <= 0;
            current_poly_inv5 <= 0;
            current_poly_b5 <= 0;
            current_poly_p5 <= 0;
            current_poly_k5 <= 0;
            current_poly_i5 <= 0;
            current_poly_j5 <= 0;
            current_poly_l5 <= 0;
            current_poly_m5 <= 0;
            current_poly_n5 <= 0;
            current_poly_o5 <= 0;
            current_poly_idx6 <= 0;
            current_poly_deg6 <= 0;
            current_poly_coeff6 <= 0;
            current_poly_exp6 <= 0;
            current_poly_inv6 <= 0;
            current_poly_b6 <= 0;
            current_poly_p6 <= 0;
            current_poly_k6 <= 0;
            current_poly_i6 <= 0;
            current_poly_j6 <= 0;
            current_poly_l6 <= 0;
            current_poly_m6 <= 0;
            current_poly_n6 <= 0;
            current_poly_o6 <= 0;
            current_poly_idx7 <= 0;
            current_poly_deg7 <= 0;
            current_poly_coeff7 <= 0;
            current_poly_exp7 <= 0;
            current_poly_inv7 <= 0;
            current_poly_b7 <= 0;
            current_poly_p7 <= 0;
            current_poly_k7 <= 0;
            current_poly_i7 <= 0;
            current_poly_j7 <= 0;
            current_poly_l7 <= 0;
            current_poly_m7 <= 0;
            current_poly_n7 <= 0;
            current_poly_o7 <= 0;
            current_poly_idx8 <= 0;
            current_poly_deg8 <= 0;
            current_poly_coeff8 <= 0;
            current_poly_exp8 <= 0;
            current_poly_inv8 <= 0;
            current_poly_b8 <= 0;
            current_poly_p8 <= 0;
            current_poly_k8 <= 0;
            current_poly_i8 <= 0;
            current_poly_j8 <= 0;
            current_poly_l8 <= 0;
            current_poly_m8 <= 0;
            current_poly_n8 <= 0;
            current_poly_o8 <= 0;
            current_poly_idx9 <= 0;
            current_poly_deg9 <= 0;
            current_poly_coeff9 <= 0;
            current_poly_exp9 <= 0;
            current_poly_inv9 <= 0;
            current_poly_b9 <= 0;
            current_poly_p9 <= 0;
            current_poly_k9 <= 0;
            current_poly_i9 <= 0;
            current_poly_j9 <= 0;
            current_poly_l9 <= 0;
            current_poly_m9 <= 0;
            current_poly_n9 <= 0;
            current_poly_o9 <= 0;
            temp_sum <= 0;
            temp_mult <= 0;
            temp_pow <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    // Load inputs
                    b_values[0] <= b0;
                    b_values[1] <= b1;
                    b_values[2] <= b2;
                    b_values[3] <= b3;
                    b_values[4] <= b4;
                    b_values[5] <= b5;
                    b_values[6] <= b6;
                    b_values[7] <= b7;
                    parent_idx[0] <= p0;
                    parent_idx[1] <= p1;
                    parent_idx[2] <= p2;
                    parent_idx[3] <= p3;
                    parent_idx[4] <= p4;
                    parent_idx[5] <= p5;
                    parent_idx[6] <= p6;
                    parent_idx[7] <= p7;
                    state <= S_BUILD;
                end

                S_BUILD: begin
                    // Build children lists
                    if (node_counter < n) begin
                        if (parent_idx[node_counter] < MAX_N && parent_idx[node_counter] != 8'hFF) begin
                            integer p = parent_idx[node_counter];
                            children[p][child_count[p]] <= node_counter;
                            child_count[p] <= child_count[p] + 1;
                        end
                        node_counter <= node_counter + 1;
                    end else begin
                        node_counter <= 0;
                        state <= S_PROCESS;
                    end
                end

                S_PROCESS: begin
                    // Process nodes
                    if (node_counter < n) begin
                        // Initialize polynomial for node
                        poly_store[node_counter][0] <= 1;
                        for (integer i = 1; i <= MAX_N; i = i + 1) begin
                            poly_store[node_counter][i] <= 0;
                        end
                        // Multiply with children polynomials
                        for (integer c = 0; c < child_count[node_counter]; c = c + 1) begin
                            integer child = children[node_counter][c];
                            // Multiply poly_store[node_counter] with poly_store[child]
                            for (integer i = 0; i <= MAX_N; i = i + 1) begin
                                poly_a[i] <= poly_store[node_counter][i];
                            end
                            for (integer i = 0; i <= MAX_N; i = i + 1) begin
                                poly_b[i] <= poly_store[child][i];
                            end
                            // Convolution
                            for (integer i = 0; i <= MAX_N; i = i + 1) begin
                                poly_res[i] <= 0;
                            end
                            for (integer i = 0; i <= MAX_N; i = i + 1) begin
                                if (poly_a[i] != 0) begin
                                    for (integer j = 0; j <= MAX_N; j = j + 1) begin
                                        if (poly_b[j] != 0 && (i + j) <= MAX_N) begin
                                            poly_res[i + j] <= (poly_res[i + j] + mod_mult(poly_a[i], poly_b[j])) % MOD;
                                        end
                                    end
                                end
                            end
                            // Copy back
                            for (integer i = 0; i <= MAX_N; i = i + 1) begin
                                poly_store[node_counter][i] <= poly_res[i];
                            end
                        end
                        // Compute g_v(x) from f_v(x)
                        temp_sum <= 0;
                        for (integer k = 0; k <= MAX_N; k = k + 1) begin
                            if (poly_store[node_counter][k] != 0) begin
                                temp_pow <= mod_pow(b_values[node_counter], k + 1);
                                temp_mult <= mod_mult(poly_store[node_counter][k], temp_pow);
                                temp_mult <= mod_mult(temp_mult, inv_int[k + 1]);
                                temp_sum <= (temp_sum + temp_mult) % MOD;
                            end
                        end
                        // Store g_v(x) as constant polynomial
                        poly_store[node_counter][0] <= temp_sum;
                        for (integer i = 1; i <= MAX_N; i = i + 1) begin
                            poly_store[node_counter][i] <= 0;
                        end
                        node_counter <= node_counter + 1;
                    end else begin
                        node_counter <= 0;
                        state <= S_COMPUTE;
                    end
                end

                S_COMPUTE: begin
                    // Compute final result for root
                    temp_sum <= 0;
                    for (integer k = 0; k <= MAX_N; k = k + 1) begin
                        if (poly_store[0][k] != 0) begin
                            temp_pow <= mod_pow(b_values[0], k + 1);
                            temp_mult <= mod_mult(poly_store[0][k], temp_pow);
                            temp_mult <= mod_mult(temp_mult, inv_int[k + 1]);
                            temp_sum <= (temp_sum + temp_mult) % MOD;
                        end
                    end
                    result <= mod_mult(temp_sum, inv_int[b_values[0]]);
                    state <= S_DONE;
                end

                S_DONE: begin
                    done <= 1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule