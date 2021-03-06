#include "openmc/tallies/filter_surface.h"

#include <sstream>

#include "openmc/error.h"
#include "openmc/surface.h"
#include "openmc/xml_interface.h"

namespace openmc {

void
SurfaceFilter::from_xml(pugi::xml_node node)
{
  surfaces_ = get_node_array<int32_t>(node, "bins");
  n_bins_ = surfaces_.size();
}

void
SurfaceFilter::initialize()
{
  // Convert surface IDs to indices of the global array.
  for (auto& s : surfaces_) {
    auto search = model::surface_map.find(s);
    if (search != model::surface_map.end()) {
      s = search->second;
    } else {
      std::stringstream err_msg;
      err_msg << "Could not find surface " << s
              << " specified on tally filter.";
      fatal_error(err_msg);
    }
  }

  // Populate the index->bin map.
  for (int i = 0; i < surfaces_.size(); i++) {
    map_[surfaces_[i]] = i;
  }
}

void
SurfaceFilter::get_all_bins(const Particle* p, int estimator,
                            FilterMatch& match) const
{
  auto search = map_.find(std::abs(p->surface)-1);
  if (search != map_.end()) {
    //TODO: off-by-one
    match.bins_.push_back(search->second + 1);
    if (p->surface < 0) {
      match.weights_.push_back(-1.0);
    } else {
      match.weights_.push_back(1.0);
    }
  }
}

void
SurfaceFilter::to_statepoint(hid_t filter_group) const
{
  Filter::to_statepoint(filter_group);
  std::vector<int32_t> surface_ids;
  for (auto c : surfaces_) surface_ids.push_back(model::surfaces[c]->id_);
  write_dataset(filter_group, "bins", surface_ids);
}

std::string
SurfaceFilter::text_label(int bin) const
{
  //TODO: off-by-one
  return "Surface " + std::to_string(model::surfaces[surfaces_[bin-1]]->id_);
}

} // namespace openmc
