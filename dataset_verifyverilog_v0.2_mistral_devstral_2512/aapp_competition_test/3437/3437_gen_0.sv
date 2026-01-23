module vacuum_tubes (
  input [7:0] L1,
  input [7:0] L2,
  input [2:0] valid_count,
  input [7:0] tube_0,
  input [7:0] tube_1,
  input [7:0] tube_2,
  input [7:0] tube_3,
  input [7:0] tube_4,
  input [7:0] tube_5,
  input [7:0] tube_6,
  input [7:0] tube_7,
  output [9:0] total_length,
  output impossible
);

  reg [9:0] max_total = 0;
  reg any_valid = 0;

  // Array of tubes for easier indexing
  wire [7:0] tubes [0:7] = '{tube_0, tube_1, tube_2, tube_3, tube_4, tube_5, tube_6, tube_7};

  // Generate all possible combinations of 4 distinct tubes
  genvar i, j, k, l;
  for (i = 0; i < 8; i = i + 1) begin : gen_i
    for (j = i + 1; j < 8; j = j + 1) begin : gen_j
      for (k = 0; k < 8; k = k + 1) begin : gen_k
        if (k != i && k != j) begin : gen_k_valid
          for (l = k + 1; l < 8; l = l + 1) begin : gen_l
            if (l != i && l != j) begin : gen_l_valid
              wire valid_combo = (i < valid_count && j < valid_count && k < valid_count && l < valid_count);
              wire sum1_valid = (tubes[i] + tubes[j]) <= L1;
              wire sum2_valid = (tubes[k] + tubes[l]) <= L2;
              wire [9:0] total = tubes[i] + tubes[j] + tubes[k] + tubes[l];

              always @* begin
                if (valid_combo && sum1_valid && sum2_valid) begin
                  any_valid = 1;
                  if (total > max_total) begin
                    max_total = total;
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  assign total_length = max_total;
  assign impossible = !any_valid;

endmodule